# frozen_string_literal: true

module Howzit
  # Topic Class
  class Topic
    attr_writer :parent

    attr_accessor :content

    attr_reader :title, :tasks, :prereqs, :postreqs, :results, :named_args

    ##
    ## Initialize a topic object
    ##
    ## @param      title    [String] The topic title
    ## @param      content  [String] The raw topic content
    ##
    def initialize(title, content)
      @title = title
      @content = content
      @parent = nil
      @nest_level = 0
      @named_args = {}
      arguments

      @tasks = gather_tasks
      @results = { total: 0, success: 0, errors: 0, message: ''.c }
    end

    # Get named arguments from title
    def arguments
      return unless @title =~ /\(.*?\) *$/

      a = @title.match(/\((?<args>.*?)\) *$/)
      args = a['args'].split(/ *, */).each(&:strip)

      args.each_with_index do |arg, idx|
        arg_name, default = arg.split(/:/).map(&:strip)

        @named_args[arg_name] = if Howzit.arguments.count >= idx + 1
                                  Howzit.arguments[idx]
                                else
                                  default
                                end
      end

      @title = @title.sub(/\(.*?\) *$/, '').strip
    end

    ##
    ## Search title and contents for a pattern
    ##
    ## @param      term  [String] the search pattern
    ##
    def grep(term)
      @title =~ /#{term}/i || @content =~ /#{term}/i
    end

    def ask_task(task)
      note = if task.type == :include
               task_count = Howzit.buildnote.find_topic(task.action)[0].tasks.count
               " (#{task_count} tasks)"
             else
               ''
             end
      q = %({bg}#{task.type.to_s.capitalize} {xw}"{bw}#{task.title}{xw}"#{note}{x}).c
      Prompt.yn(q, default: task.default)
    end

    def check_cols
      TTY::Screen.columns > 60 ? 60 : TTY::Screen.columns
    rescue StandardError
      60
    end

    # Handle run command, execute directives in topic
    def run(nested: false)
      output = []

      cols = check_cols

      if @tasks.count.positive?
        unless @prereqs.empty?
          puts TTY::Box.frame("{by}#{@prereqs.join("\n\n").wrap(cols - 4)}{x}".c, width: cols)
          res = Prompt.yn('Have the above prerequisites been met?', default: true)
          Process.exit 1 unless res

        end

        @tasks.each do |task|
          next if (task.optional || Howzit.options[:ask]) && !ask_task(task)

          run_output, total, success = task.run

          output.concat(run_output)
          @results[:total] += total

          if success
            @results[:success] += total
          else
            Howzit.console.warn %({bw}\u{2297} {br}Error running task {bw}"#{task.title}"{x}).c

            @results[:errors] += total

            break unless Howzit.options[:force]
          end
        end

        total = "{bw}#{@results[:total]}{by} #{@results[:total] == 1 ? 'task' : 'tasks'}".c
        errors = "{bw}#{@results[:errors]}{by} #{@results[:errors] == 1 ? 'error' : 'errors'}".c
        @results[:message] += if @results[:errors].zero?
                                "{bg}\u{2713} {by}Ran #{total}{x}".c
                              elsif Howzit.options[:force]
                                "{br}\u{2715} {by}Completed #{total} with #{errors}{x}".c
                              else
                                "{br}\u{2715} {by}Ran #{total}, terminated due to error{x}".c
                              end
      else
        Howzit.console.warn "{r}--run: No {br}@directive{xr} found in {bw}#{@title}{x}".c
      end

      output.push(@results[:message]) if Howzit.options[:log_level] < 2 && !nested

      puts TTY::Box.frame("{bw}#{@postreqs.join("\n\n").wrap(cols - 4)}{x}".c, width: cols) unless @postreqs.empty?

      output
    end

    def title_option(color, topic, keys, opt)
      option = colored_option(color, topic, keys)
      "#{opt[:single] ? 'From' : 'Include'} #{topic.title}#{option}:"
    end

    def colored_option(color, topic, keys)
      if topic.tasks.empty?
        ''
      else
        optional = keys[:optional] =~ /[?!]+/ ? true : false
        default = keys[:optional] =~ /!/ ? false : true
        if optional
          colored_yn(color, default)
        else
          ''
        end
      end
    end

    def colored_yn(color, default)
      if default
        " {xKk}[{gbK}Y{xKk}/{dbwK}n{xKk}]{x}#{color}".c
      else
        " {xKk}[{dbwK}y{xKk}/{bgK}N{xKk}]{x}#{color}".c
      end
    end

    ##
    ## Handle an include statement
    ##
    ## @param      keys  [Hash] The symbolized keys and values from the regex
    ##                   that found the statement
    ## @param      opt   [Hash] Options
    ##
    def process_include(keys, opt)
      output = []

      if keys[:action] =~ / *\[(.*?)\] *$/
        Howzit.named_arguments = @named_args
        Howzit.arguments = Regexp.last_match(1).split(/ *, */).map!(&:render_arguments)
      end

      matches = Howzit.buildnote.find_topic(keys[:action].sub(/ *\[.*?\] *$/, ''))

      return [] if matches.empty?

      topic = matches[0]

      rule = '{kKd}'
      color = '{Kyd}'
      title = title_option(color, topic, keys, opt)
      options = { color: color, hr: '.', border: rule }

      output.push("#{'> ' * @nest_level}#{title}".format_header(options)) unless Howzit.inclusions.include?(topic)

      if opt[:single] && Howzit.inclusions.include?(topic)
        output.push("#{'> ' * @nest_level}#{title} included above".format_header(options))
      elsif opt[:single]
        @nest_level += 1

        output.concat(topic.print_out({ single: true, header: false }))
        output.push("#{'> ' * @nest_level}...".format_header(options))
        @nest_level -= 1
      end
      Howzit.inclusions.push(topic)

      output
    end

    def color_directive_yn(keys)
      optional, default = define_optional(keys[:optional])
      if optional
        default ? ' {xk}[{g}Y{xk}/{dbw}n{xk}]{x}'.c : ' {xk}[{dbw}y{xk}/{g}N{xk}]{x}'.c
      else
        ''
      end
    end

    def process_directive(keys)
      cmd = keys[:cmd]
      obj = keys[:action]
      title = keys[:title].empty? ? obj : keys[:title].strip
      title = Howzit.options[:show_all_code] ? obj : title
      option = color_directive_yn(keys)
      icon = case cmd
             when 'run'
               "\u{25B6}"
             when 'copy'
               "\u{271A}"
             when /open|url/
               "\u{279A}"
             end

      "{bmK}#{icon} {bwK}#{title.preserve_escapes}{x}#{option}".c
    end

    def define_optional(optional)
      is_optional = optional =~ /[?!]+/ ? true : false
      default = optional =~ /!/ ? false : true
      [is_optional, default]
    end

    def title_code_block(keys)
      if keys[:title].length.positive?
        "Block: #{keys[:title]}#{color_directive_yn(keys)}"
      else
        "Code Block#{color_directive_yn(keys)}"
      end
    end

    # Output a topic with fancy title and bright white text.
    #
    # @param      options  [Hash] The options
    #
    # @return     [Array] array of formatted lines
    #
    def print_out(options = {})
      defaults = { single: false, header: true }
      opt = defaults.merge(options)

      output = []
      if opt[:header]
        output.push(@title.format_header)
        output.push('')
      end
      topic = @content.dup
      unless Howzit.options[:show_all_code]
        topic.gsub!(/(?mix)^(`{3,})run([?!]*)\s*
                    ([^\n]*)[\s\S]*?\n\1\s*$/, '@@@run\2 \3')
      end
      topic.split(/\n/).each do |l|
        case l
        when /@(before|after|prereq|end)/
          next
        when /@include(?<optional>[!?]{1,2})?\((?<action>[^)]+)\)/
          output.concat(process_include(Regexp.last_match.named_captures.symbolize_keys, opt))
        when /@(?<cmd>run|copy|open|url)(?<optional>[?!]{1,2})?\((?<action>.*?)\) *(?<title>.*?)$/
          output.push(process_directive(Regexp.last_match.named_captures.symbolize_keys))
        when /(?<fence>`{3,})run(?<optional>[!?]{1,2})? *(?<title>.*?)$/i
          desc = title_code_block(Regexp.last_match.named_captures.symbolize_keys)
          output.push("{bmK}\u{25B6} {bwK}#{desc}{x}\n```".c)
        when /@@@run(?<optional>[!?]{1,2})? *(?<title>.*?)$/i
          output.push("{bmK}\u{25B6} {bwK}#{title_code_block(Regexp.last_match.named_captures.symbolize_keys)}{x}".c)
        else
          l.wrap!(Howzit.options[:wrap]) if Howzit.options[:wrap].positive?
          output.push(l)
        end
      end
      Howzit.named_arguments = @named_args
      output.push('').map(&:render_arguments)
    end

    include Comparable
    def <=>(other)
      @title <=> other.title
    end

    def define_task_args(keys)
      cmd = keys[:cmd]
      obj = keys[:action]
      title = keys[:title].nil? ? obj : keys[:title].strip
      title = Howzit.options[:show_all_code] ? obj : title
      task_args = { type: :include,
                    arguments: nil,
                    title: title,
                    action: obj,
                    parent: self }
      case cmd
      when /include/i
        if title =~ /\[(.*?)\] *$/
          Howzit.named_arguments = @named_args
          args = Regexp.last_match(1).split(/ *, */).map(&:render_arguments)
          Howzit.arguments = args
          arguments
          title.sub!(/ *\[.*?\] *$/, '')
        end

        task_args[:type] = :include
        task_args[:arguments] = Howzit.named_arguments
      when /run/i
        task_args[:type] = :run
      when /copy/i
        task_args[:type] = :copy
        task_args[:action] = Shellwords.escape(obj)
      when /open|url/i
        task_args[:type] = :open
      end

      task_args
    end

    private

    ##
    ## Collect all directives in the topic content
    ##
    ## @return     [Array] array of Task objects
    ##
    def gather_tasks
      runnable = []
      @prereqs = @content.scan(/(?<=@before\n).*?(?=\n@end)/im).map(&:strip)
      @postreqs = @content.scan(/(?<=@after\n).*?(?=\n@end)/im).map(&:strip)

      rx = /(?mix)(?:
            @(?<cmd>include|run|copy|open|url)(?<optional>[!?]{1,2})?\((?<action>[^)]*?)\)(?<title>[^\n]+)?
            |(?<fence>`{3,})run(?<optional2>[!?]{1,2})?(?<title2>[^\n]+)?(?<block>.*?)\k<fence>
            )/
      matches = []
      @content.scan(rx) { matches << Regexp.last_match }
      matches.each do |m|
        c = m.named_captures.symbolize_keys
        Howzit.named_arguments = @named_args

        if c[:cmd].nil?
          optional, default = define_optional(c[:optional2])
          title = c[:title2].nil? ? '' : c[:title2].strip
          block = c[:block]&.strip
          runnable << Howzit::Task.new({ type: :block,
                                         title: title,
                                         action: block,
                                         parent: self },
                                       optional: optional,
                                       default: default)
        else
          optional, default = define_optional(c[:optional])
          runnable << Howzit::Task.new(define_task_args(c),
                                       optional: optional,
                                       default: default)
        end
      end

      runnable
    end
  end
end
