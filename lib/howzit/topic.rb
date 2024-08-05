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

    # Handle run command, execute directives in topic
    def run(nested: false)
      output = []

      cols = begin
        TTY::Screen.columns > 60 ? 60 : TTY::Screen.columns
      rescue StandardError
        60
      end

      if @tasks.count.positive?
        unless @prereqs.empty?
          puts TTY::Box.frame("{by}#{@prereqs.join("\n\n").wrap(cols - 4)}{x}".c, width: cols)
          res = Prompt.yn('Have the above prerequisites been met?', default: true)
          Process.exit 1 unless res

        end

        @tasks.each do |task|
          if task.optional || Howzit.options[:ask]
            note = if task.type == :include
                     task_count = Howzit.buildnote.find_topic(task.action)[0].tasks.count
                     " (#{task_count} tasks)"
                   else
                     ''
                   end
            q = %({bg}#{task.type.to_s.capitalize} {xw}"{bw}#{task.title}{xw}"#{note}{x}).c
            res = Prompt.yn(q, default: task.default)
            next unless res

          end
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
      topic.gsub!(/(?mi)^(`{3,})run([?!]*) *([^\n]*)[\s\S]*?\n\1\s*$/, '@@@run\2 \3') unless Howzit.options[:show_all_code]
      topic.split(/\n/).each do |l|
        case l
        when /@(before|after|prereq|end)/
          next
        when /@include(?<optional>[!?]{1,2})?\((?<action>[^\)]+)\)/
          m = Regexp.last_match.named_captures.symbolize_keys

          if m[:action] =~ / *\[(.*?)\] *$/
            Howzit.named_arguments = @named_args
            Howzit.arguments = Regexp.last_match(1).split(/ *, */).map!(&:render_arguments)
          end

          matches = Howzit.buildnote.find_topic(m[:action].sub(/ *\[.*?\] *$/, ''))

          unless matches.empty?
            i_topic = matches[0]

            rule = '{kKd}'
            color = '{Kyd}'
            option = if i_topic.tasks.empty?
                       ''
                     else
                       optional = m[:optional] =~ /[?!]+/ ? true : false
                       default = m[:optional] =~ /!/ ? false : true
                       if optional
                         default ? " {xKk}[{gbK}Y{xKk}/{dbwK}n{xKk}]{x}#{color}".c : " {xKk}[{dbwK}y{xKk}/{bgK}N{xKk}]{x}#{color}".c
                       else
                         ''
                       end
                     end
            title = "#{opt[:single] ? 'From' : 'Include'} #{i_topic.title}#{option}:"
            options = { color: color, hr: '.', border: rule }
            unless Howzit.inclusions.include?(i_topic)
              output.push("#{'> ' * @nest_level}#{title}".format_header(options))
            end

            if opt[:single] && Howzit.inclusions.include?(i_topic)
              output.push("#{'> ' * @nest_level}#{title} included above".format_header(options))
            elsif opt[:single]
              @nest_level += 1

              output.concat(i_topic.print_out({ single: true, header: false }))
              output.push("#{'> ' * @nest_level}...".format_header(options))
              @nest_level -= 1
            end
            Howzit.inclusions.push(i_topic)
          end
        when /@(?<cmd>run|copy|open|url)(?<optional>[?!]{1,2})?\((?<action>.*?)\) *(?<title>.*?)$/
          m = Regexp.last_match.named_captures.symbolize_keys
          cmd = m[:cmd]
          obj = m[:action]
          title = m[:title].empty? ? obj : m[:title].strip
          title = Howzit.options[:show_all_code] ? obj : title
          optional = m[:optional] =~ /[?!]+/ ? true : false
          default = m[:optional] =~ /!/ ? false : true
          option = if optional
                     default ? ' {xk}[{g}Y{xk}/{dbw}n{xk}]{x}'.c : ' {xk}[{dbw}y{xk}/{g}N{xk}]{x}'.c
                   else
                     ''
                   end
          icon = case cmd
                 when 'run'
                   "\u{25B6}"
                 when 'copy'
                   "\u{271A}"
                 when /open|url/
                   "\u{279A}"
                 end

          output.push("{bmK}#{icon} {bwK}#{title.preserve_escapes}{x}#{option}".c)
        when /(?<fence>`{3,})run(?<optional>[!?]{1,2})? *(?<title>.*?)$/i
          m = Regexp.last_match.named_captures.symbolize_keys
          optional = m[:optional] =~ /[?!]+/ ? true : false
          default = m[:optional] =~ /!/ ? false : true
          option = if optional
                     default ? ' {xk}[{g}Y{xk}/{dbw}n{xk}]{x}'.c : ' {xk}[{dbw}y{xk}/{g}N{xk}]{x}'.c
                   else
                     ''
                   end
          desc = m[:title].length.positive? ? "Block: #{m[:title]}#{option}" : "Code Block#{option}"
          output.push("{bmK}\u{25B6} {bwK}#{desc}{x}\n```".c)
        when /@@@run(?<optional>[!?]{1,2})? *(?<title>.*?)$/i
          m = Regexp.last_match.named_captures.symbolize_keys
          optional = m[:optional] =~ /[?!]+/ ? true : false
          default = m[:optional] =~ /!/ ? false : true
          option = if optional
                     default ? ' {xk}[{g}Y{xk}/{dbw}n{xk}]{x}'.c : ' {xk}[{dbw}y{xk}/{g}N{xk}]{x}'.c
                   else
                     ''
                   end
          desc = m[:title].length.positive? ? "Block: #{m[:title]}#{option}" : "Code Block#{option}"
          output.push("{bmK}\u{25B6} {bwK}#{desc}{x}".c)
        else
          l.wrap!(Howzit.options[:wrap]) if Howzit.options[:wrap].positive?
          output.push(l)
        end
      end
      Howzit.named_arguments = @named_args
      output.push('').map(&:render_arguments)
    end

    include Comparable
    def <=>(topic)
      @title <=> topic.title
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
          optional = c[:optional2] =~ /[?!]{1,2}/ ? true : false
          default = c[:optional2] =~ /!/ ? false : true
          title = c[:title2].nil? ? '' : c[:title2].strip
          block = c[:block]&.strip
          runnable << Howzit::Task.new({ type: :block,
                                         title: title,
                                         action: block,
                                         parent: self },
                                       optional: optional,
                                       default: default)
        else
          cmd = c[:cmd]
          optional = c[:optional] =~ /[?!]{1,2}/ ? true : false
          default = c[:optional] =~ /!/ ? false : true
          obj = c[:action]
          title = c[:title].nil? ? obj : c[:title].strip
          title = Howzit.options[:show_all_code] ? obj : title
          case cmd
          when /include/i
            # matches = Howzit.buildnote.find_topic(obj)
            # unless matches.empty? || Howzit.inclusions.include?(matches[0].title)
            #   tasks = matches[0].tasks.map do |inc|
            #     Howzit.inclusions.push(matches[0].title)
            #     inc.parent = matches[0]
            #     inc
            #   end
            #   runnable.concat(tasks)
            # end
            args = []
            if title =~ /\[(.*?)\] *$/
              Howzit.named_arguments = @named_args
              args = Regexp.last_match(1).split(/ *, */).map(&:render_arguments)
              Howzit.arguments = args
              arguments
              title.sub!(/ *\[.*?\] *$/, '')
            end

            runnable << Howzit::Task.new({ type: :include,
                                           arguments: Howzit.named_arguments,
                                           title: title,
                                           action: obj,
                                           parent: self },
                                         optional: optional,
                                         default: default)
          when /run/i
            # warn "{bg}Running {bw}#{obj}{x}".c if Howzit.options[:log_level] < 2
            runnable << Howzit::Task.new({ type: :run,
                                           title: title,
                                           action: obj,
                                           parent: self },
                                         optional: optional,
                                         default: default)
          when /copy/i
            # warn "{bg}Copied {bw}#{obj}{bg} to clipboard{x}".c if Howzit.options[:log_level] < 2
            runnable << Howzit::Task.new({ type: :copy,
                                           title: title,
                                           action: Shellwords.escape(obj),
                                           parent: self },
                                         optional: optional,
                                         default: default)
          when /open|url/i
            runnable << Howzit::Task.new({ type: :open,
                                           title: title,
                                           action: obj,
                                           parent: self },
                                         optional: optional,
                                         default: default)
          end
        end
      end

      runnable
    end
  end
end
