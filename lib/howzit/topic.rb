# frozen_string_literal: true

module Howzit
  # Topic Class
  class Topic
    attr_writer :parent

    attr_accessor :content, :parent_topic

    attr_reader :title, :tasks, :prereqs, :postreqs, :results, :named_args, :directives, :arg_definitions, :source_file,
                :level, :subtopics

    ##
    ## Initialize a topic object
    ##
    ## @param      title       [String] The topic title
    ## @param      content     [String] The raw topic content
    ## @param      metadata    [Hash] Optional metadata hash
    ## @param      source_file [String] Optional path to the build note file this topic came from
    ## @param      level       [Integer] Markdown header level (2 for ##, 3 for ###, etc.)
    ## @param      positional  [Array] Values to bind to the title's (arguments),
    ##                         overriding CLI arguments
    ##
    def initialize(title, content, metadata = nil, source_file: nil, level: 2, positional: nil)
      @raw_title = title
      @title = title
      @content = content
      @parent = nil
      @parent_topic = nil
      @subtopics = []
      @level = level
      @nest_level = 0
      @named_args = {}
      @metadata = metadata
      @source_file = source_file
      arguments(from_cli_snapshot: positional.nil?, positional: positional)

      @directives = parse_directives_with_conditionals
      @tasks = gather_tasks
      @results = { total: 0, success: 0, errors: 0, message: ''.c }
    end

    ##
    ## Nest a topic under this one (a deeper header following this topic)
    ##
    ## @param      topic  [Topic] The subtopic
    ##
    def add_subtopic(topic)
      topic.parent_topic = self
      @subtopics << topic
    end

    ##
    ## Tasks from this topic and all nested subtopics, in run order
    ##
    ## @return     [Array] Array of Task objects
    ##
    def all_tasks
      @tasks + @subtopics.flat_map(&:all_tasks)
    end

    ##
    ## Parent topics from nearest to outermost
    ##
    ## @return     [Array] Array of Topic objects
    ##
    def ancestors
      list = []
      node = @parent_topic
      while node
        list << node
        node = node.parent_topic
      end
      list
    end

    ##
    ## A copy of this topic with bracketed arguments (e.g.
    ## `@include(Deploy [prod])` or `default: Deploy[prod]`) bound to the
    ## title's (arguments). Tasks are rebuilt so commands render with them.
    ##
    ## @param      args  [Array] Positional values
    ##
    ## @return     [Topic] a new Topic, or self if no args given
    ##
    def with_arguments(args)
      return self if args.nil? || args.empty?

      topic = Topic.new(@raw_title, @content, @metadata, source_file: @source_file, level: @level, positional: args)
      topic.parent = @parent
      topic.parent_topic = @parent_topic
      topic.subtopics.concat(@subtopics)
      topic
    end

    # Get named arguments from title
    # from_cli_snapshot: use Howzit.cli_topic_positional_args (argv after `--`) so earlier
    # topics' gather_tasks cannot clobber positional binding. positional: binds
    # bracketed arguments from @include [a,b] and default: (see #with_arguments).
    def arguments(from_cli_snapshot: false, positional: nil)
      @arg_definitions = []
      return unless @title =~ /\(.*?\) *$/

      positional ||= if from_cli_snapshot
                       # Specs / non-CLI: leave unset to keep using Howzit.arguments
                       if Howzit.cli_topic_positional_args.nil?
                         Howzit.arguments || []
                       else
                         Howzit.cli_topic_positional_args
                       end
                     else
                       Howzit.arguments || []
                     end

      a = @title.match(/\((?<args>.*?)\) *$/)
      args = a['args'].split(/ *, */).each(&:strip)

      args.each_with_index do |arg, idx|
        arg_name, default = arg.split(/:/).map(&:strip)
        # Store original definition for display purposes
        @arg_definitions << (default ? "#{arg_name}:#{default}" : arg_name)

        @named_args[arg_name] = if positional && positional.count >= idx + 1
                                  positional[idx]
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
               task_count = Howzit.buildnote.find_topic(task.action)[0].all_tasks.count
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

    ##
    ## Handle run command, execute directives in topic, then in each subtopic
    ##
    ## @param      nested       [Boolean] Suppress the summary message (topic is being included)
    ## @param      as_subtopic  [Boolean] Topic is being run as part of a parent topic
    ##
    ## @return     [Array] output lines
    ##
    def run(nested: false, as_subtopic: false)
      # The outermost run shows @before/@after notes for the whole tree
      return run_topic(nested: nested, as_subtopic: as_subtopic) if Howzit.topic_run_active

      Howzit.topic_run_active = true
      begin
        cols = check_cols
        confirm_prereqs(cols) if all_tasks.any? || sequential?
        output = run_topic(nested: nested, as_subtopic: as_subtopic)
        show_postreqs(cols)
        output
      ensure
        Howzit.topic_run_active = false
      end
    end

    ##
    ## @before notes for this topic, the topics it includes, and its
    ## subtopics, in document order
    ##
    ## @return     [Array] rendered notes
    ##
    def all_prereqs
      collect_notes(:prereqs)
    end

    ##
    ## @after notes for this topic, the topics it includes, and its
    ## subtopics, in document order
    ##
    ## @return     [Array] rendered notes
    ##
    def all_postreqs
      collect_notes(:postreqs)
    end

    ##
    ## Gather notes recursively through @include tasks and subtopics
    ##
    ## @param      kind  [Symbol] :prereqs or :postreqs
    ## @param      args  [Array] Bracketed arguments from an @include
    ## @param      seen  [Array] Titles of topics already collected
    ##
    def collect_notes(kind, args = nil, seen = [])
      return [] if seen.include?(@title)

      seen << @title
      notes = render_notes(kind == :prereqs ? @prereqs : @postreqs, args)
      @tasks.select { |task| task.type == :include }.each do |task|
        topic = Howzit.buildnote.find_topic(task.action.sub(/ *\[.*?\] *$/, ''))[0]
        notes.concat(topic.collect_notes(kind, task.include_args, seen)) if topic
      end
      notes + @subtopics.flat_map { |sub| sub.collect_notes(kind, nil, seen) }
    end

    ##
    ## Whether the topic contains conditional directives and must be run sequentially
    ##
    def sequential?
      @directives&.any?(&:conditional?) || false
    end

    ##
    ## Whether this topic or any subtopic contains directives,
    ## including non-task directives like @set_var and @log_level
    ##
    def directives?
      @directives&.any? || @subtopics.any?(&:directives?)
    end

    def halted?
      @results[:errors].positive? && !Howzit.options[:force]
    end

    def confirm_prereqs(cols)
      prereqs = all_prereqs
      return if prereqs.empty?

      begin
        puts TTY::Box.frame("{by}#{prereqs.join("\n\n").wrap(cols - 4)}{x}".c, width: cols)
      rescue Errno::EPIPE
        # Pipe closed, ignore
      end
      res = Prompt.yn('Have the above prerequisites been met?', default: true)
      Process.exit 1 unless res
    end

    def show_postreqs(cols)
      postreqs = all_postreqs
      return if postreqs.empty?

      # Wrap each line individually to preserve structure
      wrapped_content = postreqs.join("\n\n").split(/\n/).map { |line| line.wrap(cols - 4) }.join("\n")
      puts TTY::Box.frame("{bw}#{wrapped_content}{x}".c, width: cols)
    rescue Errno::EPIPE
      # Pipe closed, ignore
    end

    def results_message
      total = "{bw}#{@results[:total]}{by} #{@results[:total] == 1 ? 'task' : 'tasks'}".c
      errors = "{bw}#{@results[:errors]}{by} #{@results[:errors] == 1 ? 'error' : 'errors'}".c
      if @results[:errors].zero?
        "{bg}\u{2713} {by}Ran #{total}{x}".c
      elsif Howzit.options[:force]
        "{br}\u{2715} {by}Completed #{total} with #{errors}{x}".c
      else
        "{br}\u{2715} {by}Ran #{total}, terminated due to error{x}".c
      end
    end

    ##
    ## Run tasks without conditional evaluation
    ##
    def run_tasks(output)
      @tasks.each_with_index do |task, idx|
        next if (task.optional || Howzit.options[:ask]) && !ask_task(task)

        run_output, total, success = task.run

        output.concat(run_output)
        record_task_result(task, total, success)
        next unless halted?

        log_skipped_tasks(@tasks[(idx + 1)..])
        break
      end
      output
    end

    ##
    ## Add a task's results to the topic totals and the run report
    ##
    ## @param      task     [Task] The task that ran
    ## @param      total    [Integer] Number of tasks it represents
    ## @param      success  [Boolean] Whether it succeeded
    ##
    def record_task_result(task, total, success)
      if task.type == :include && task.include_results
        %i[total success errors].each { |key| @results[key] += task.include_results[key] }
      else
        @results[:total] += total
        @results[success ? :success : :errors] += total
      end

      log_task_result(task, success)
      Howzit.console.warn %({bw}\u{2297} {br}Error running task {bw}"#{task.title}"{x}).c unless success
    end

    ##
    ## Log tasks that won't run because an earlier task failed.
    ## Include tasks are expanded to the tasks of the included topic.
    ##
    ## @param      tasks  [Array] Task objects
    ## @param      seen   [Array] Titles of included topics already expanded
    ##
    def log_skipped_tasks(tasks, seen = [])
      return unless Howzit.options[:run]

      Howzit.run_log ||= []
      tasks.each do |task|
        if task.type == :include
          topic = Howzit.buildnote.find_topic(task.action)[0]
          next if topic.nil? || seen.include?(topic.title)

          topic.log_skipped_tasks(topic.all_tasks, seen + [topic.title])
          next
        end

        topic_title = task.parent.is_a?(Topic) ? task.parent.title : @title
        Howzit.run_log << { topic: topic_title, task: task_log_title(task), success: false, skipped: true }
      end
    end

    ##
    ## Run each subtopic in order, adding its results to this topic's
    ##
    def run_subtopics(output)
      @subtopics.each_with_index do |sub, idx|
        output.concat(sub.run(nested: true, as_subtopic: true))
        %i[total success errors].each { |key| @results[key] += sub.results[key] }
        next unless halted?

        log_skipped_tasks(@subtopics[(idx + 1)..].flat_map(&:all_tasks))
        break
      end
      output
    end

    def title_option(color, topic, keys, opt)
      option = colored_option(color, topic, keys)
      "#{opt[:single] ? 'From' : 'Include'} #{topic.title}#{option}:"
    end

    def colored_option(color, topic, keys)
      if topic.all_tasks.empty?
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
        Howzit.named_arguments ||= {}
        Howzit.named_arguments.merge!(@named_args) if @named_args
        Howzit.arguments = Regexp.last_match(1).split(/ *, */).map!(&:render_arguments)
      end

      matches = Howzit.buildnote.find_topic(keys[:action].sub(/ *\[.*?\] *$/, ''))

      return [] if matches.empty?

      topic = matches[0]
      return [] if topic.nil?

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
        # Include argument definitions in header if present
        header_title = @title.dup
        unless @arg_definitions.nil? || @arg_definitions.empty?
          formatted_args = @arg_definitions.map { |arg| format_arg_definition(arg) }.join('{l}, '.c)
          header_title += " {l}({x}#{formatted_args}{l}){x}".c
        end
        header_opts = opt[:subtopic] ? { color: '{bc}', hr: "\u{2508}" } : {}
        output.push(header_title.format_header(header_opts))
        output.push('')
      end
      # Process conditional blocks first
      metadata = @metadata || Howzit.buildnote&.metadata
      topic = ConditionalContent.process(@content.dup, { metadata: metadata })
      unless Howzit.options[:show_all_code]
        topic.gsub!(/(?mix)^(`{3,})run([?!]*)\s*
                    ([^\n]*)[\s\S]*?\n\1\s*$/, '@@@run\2 \3')
      end
      topic.split(/\n/).each do |l|
        case l
        when /@(before|after|prereq|end|if|unless)/
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
          # Highlight variable placeholders in content
          output.push(highlight_variables(l))
        end
      end
      Howzit.named_arguments = @named_args
      output.push('')
      @subtopics.each { |sub| output.concat(sub.print_out(opt.merge(header: true, subtopic: true))) }
      output
    end

    ##
    ## Format an argument definition with syntax highlighting
    ## Parentheses in blue, variable name in bright white, default in yellow
    ##
    ## @param      arg  [String] The argument definition (e.g., "var" or "var:default")
    ##
    ## @return     [String] Colorized argument definition
    ##
    def format_arg_definition(arg)
      if arg.include?(':')
        name, default = arg.split(':', 2)
        "{bw}#{name}{l}:{y}#{default}{x}".c
      else
        "{bw}#{arg}{x}".c
      end
    end

    ##
    ## Highlight variable placeholders in content
    ## Format: ${variable} or ${variable:default}
    ## Dollar sign and braces in blue, variable name in bright white, default in yellow
    ##
    ## @param      text  [String] The text to process
    ##
    ## @return     [String] Text with highlighted variables
    ##
    def highlight_variables(text)
      text.gsub(/\$\{([A-Za-z0-9_]+)(?::([^}]*))?\}/) do
        var_name = Regexp.last_match(1)
        default = Regexp.last_match(2)
        if default
          "{l}\\$\\{{bw}#{var_name}{l}:{y}#{default}{l}\\}{x}".c
        else
          "{l}\\$\\{{bw}#{var_name}{l}\\}{x}".c
        end
      end
    end

    include Comparable
    def <=>(other)
      @title <=> other.title
    end

    def define_task_args(keys)
      cmd = keys[:cmd]
      obj = keys[:action]
      # Extract and clean the title
      raw_title = keys[:title]
      # Determine the title: use provided title if available, otherwise use action
      title = if raw_title.nil? || raw_title.to_s.strip.empty?
                obj
              else
                raw_title.to_s.strip
              end
      # Store the actual title (not overridden by show_all_code - that's only for display)
      task_args = { type: :include,
                    arguments: nil,
                    title: title.dup, # Make a copy to avoid reference issues
                    action: obj,
                    parent: self }
      # Set named_arguments before processing titles for variable substitution
      # Merge with existing named_arguments to preserve @set_var variables
      Howzit.named_arguments ||= {}
      Howzit.named_arguments.merge!(@named_args) if @named_args
      case cmd
      when /include/i
        if title =~ /\[(.*?)\] *$/
          args = Regexp.last_match(1).split(/ *, */).map(&:render_arguments)
          Howzit.arguments = args
          task_args[:include_args] = args
          title.sub!(/ *\[.*?\] *$/, '')
        end
        # Apply variable substitution to title after bracket processing
        task_args[:title] = title.render_arguments

        task_args[:type] = :include
        task_args[:arguments] = Howzit.named_arguments
      when /run/i
        task_args[:type] = :run
        task_args[:title] = title.render_arguments
        # Parse log_level from action if present (format: script, log_level=level)
        if obj =~ /,\s*log_level\s*=\s*(\w+)/i
          log_level = Regexp.last_match(1).downcase
          task_args[:log_level] = log_level
          # Remove log_level parameter from action
          obj = obj.sub(/,\s*log_level\s*=\s*\w+/i, '').strip
        end
        task_args[:action] = obj
      when /copy/i
        task_args[:type] = :copy
        task_args[:action] = Shellwords.escape(obj)
        task_args[:title] = title.render_arguments
      when /open|url/i
        task_args[:type] = :open
        task_args[:title] = title.render_arguments
      end

      task_args
    end

    private

    def run_topic(nested:, as_subtopic:)
      @results = { total: 0, success: 0, errors: 0, message: ''.c }
      output = []

      if sequential?
        run_sequential(output: output)
      elsif @tasks.any?
        run_tasks(output)
      elsif all_tasks.empty? && !as_subtopic && !directives?
        Howzit.console.warn "{r}--run: No {br}@directive{xr} found in {bw}#{@title}{x}".c
      end

      if halted?
        log_skipped_tasks(@subtopics.flat_map(&:all_tasks))
      else
        run_subtopics(output)
      end

      if @results[:total].positive? || (all_tasks.any? && !sequential?)
        @results[:message] += results_message
        output.push(@results[:message]) if Howzit.options[:log_level] < 2 && !nested && !Howzit.options[:run]
      end

      output
    end

    ##
    ## Render notes with this topic's variables, plus any bracketed
    ## @include arguments bound to its title parameters
    ##
    def render_notes(notes, args)
      return [] if notes.empty?

      previous = Howzit.named_arguments
      begin
        Howzit.named_arguments = (previous || {}).merge(@named_args.compact).merge(bound_arguments(args))
        notes.map(&:render_arguments)
      ensure
        Howzit.named_arguments = previous
      end
    end

    def bound_arguments(args)
      return {} if args.nil? || args.empty?

      names = @arg_definitions.map { |definition| definition.split(':', 2).first }
      names.zip(args).to_h.compact
    end

    ##
    ## Collect all directives in the topic content
    ##
    ## @return     [Array] array of Task objects
    ##
    def log_task_result(task, success)
      return unless Howzit.options[:run]
      return if task.type == :include

      Howzit.run_log ||= []
      Howzit.run_log << {
        topic: @title,
        task: task_log_title(task),
        success: success ? true : false,
        exit_status: task.last_status
      }
    end

    def task_log_title(task)
      title = (task.title || '').strip
      title = (task.action || '').strip.split(/\n/).first.to_s.strip if title.empty?
      title.empty? ? task.type.to_s.capitalize : title
    end

    def gather_tasks
      runnable = []
      # Process conditional blocks first
      # Set named_arguments before processing so conditions can access them
      Howzit.named_arguments ||= {}
      Howzit.named_arguments.merge!(@named_args) if @named_args

      # Process @set_var directives before gathering tasks (for non-sequential path)
      # This ensures variables are available when task actions are rendered
      if @directives && !@directives.any?(&:conditional?)
        @directives.each do |dir|
          next unless dir.set_var?

          value = dir.var_value
          if value
            # Check for command substitution: backticks or $()
            if value =~ /^`(.+)`$/ || value =~ /^\$\((.+)\)$/
              command = Regexp.last_match(1).strip
              # Apply variable substitution to command before execution
              command = command.render_arguments
              # Execute command and capture output
              begin
                value = `#{command}`.strip
              rescue StandardError => e
                Howzit.console.warn("Error executing command in @set_var: #{e.message}")
                value = ''
              end
            else
              # Apply variable substitution to the value (in case it references other variables)
              value = value.render_arguments
            end
          end

          Howzit.named_arguments[dir.var_name] = value
        end
      end

      metadata = @metadata || Howzit.buildnote&.metadata
      processed_content = ConditionalContent.process(@content, { metadata: metadata })

      @prereqs = processed_content.scan(/(?<=@before\n).*?(?=\n@end)/im).map(&:strip)
      @postreqs = processed_content.scan(/(?<=@after\n).*?(?=\n@end)/im).map(&:strip)

      rx = /(?mix)(?:
            @(?<cmd>include|run|copy|open|url)(?<optional>[!?]{1,2})?\((?<action>[^)]*?)\)(?<title>[^\n]+)?
            |(?<fence>`{3,})run(?<optional2>[!?]{1,2})?(?<title2>[^\n]+)?(?<block>.*?)\k<fence>
            )/
      matches = []
      processed_content.scan(rx) { matches << Regexp.last_match }
      matches.each do |m|
        c = m.named_captures.symbolize_keys
        Howzit.named_arguments ||= {}
        Howzit.named_arguments.merge!(@named_args) if @named_args

        if c[:cmd].nil?
          optional, default = define_optional(c[:optional2])
          title = c[:title2].nil? ? '' : c[:title2].strip
          # Apply variable substitution to block title
          title = title.render_arguments if title && !title.empty?
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

    ##
    ## Parse directives with conditional context for sequential evaluation
    ##
    ## @return     [Array] Array of Directive objects
    ##
    def parse_directives_with_conditionals
      directives = []
      lines = @content.split(/\n/)
      conditional_stack = [] # Array of directive indices for @if/@unless directives
      current_branch_index = nil # Track current @if/@elsif/@else branch index
      line_num = 0
      in_code_block = false
      code_block_lines = []
      code_block_fence = nil
      code_block_title = nil
      code_block_optional = nil

      # Extract prereqs and postreqs from raw content
      @prereqs = @content.scan(/(?<=@before\n).*?(?=\n@end)/im).map(&:strip)
      @postreqs = @content.scan(/(?<=@after\n).*?(?=\n@end)/im).map(&:strip)

      lines.each do |line|
        line_num += 1

        # Handle code blocks (fenced code)
        if line =~ /^(`{3,})run([?!]*)\s*(.*?)$/i && !in_code_block
          in_code_block = true
          code_block_fence = Regexp.last_match(1)
          code_block_optional = Regexp.last_match(2)
          code_block_title = Regexp.last_match(3).strip
          code_block_lines = []
          next
        elsif in_code_block
          if line =~ /^#{Regexp.escape(code_block_fence)}\s*$/
            # End of code block
            block_content = code_block_lines.join("\n")
            optional, default = define_optional(code_block_optional)
            conditional_path = conditional_stack.dup
            # If we're inside an @elsif/@else branch, include it in the path
            conditional_path << current_branch_index if current_branch_index
            directives << Howzit::Directive.new(
              type: :task,
              content: {
                type: :block,
                title: code_block_title,
                action: block_content,
                arguments: nil
              },
              optional: optional,
              default: default,
              line_number: line_num,
              conditional_path: conditional_path
            )
            in_code_block = false
            code_block_lines = []
            code_block_fence = nil
          else
            code_block_lines << line
          end
          next
        end

        # Handle conditional directives
        if line =~ /^@(if|unless)\s+(.+)$/i
          directive_type = Regexp.last_match(1).downcase
          condition = Regexp.last_match(2).strip
          directive_index = directives.length
          conditional_stack << directive_index
          current_branch_index = directive_index
          directives << Howzit::Directive.new(
            type: directive_type.to_sym,
            condition: condition,
            directive_type: directive_type,
            line_number: line_num,
            conditional_path: conditional_stack[0..-2].dup
          )
          next
        elsif line =~ /^@elsif\s+(.+)$/i
          condition = Regexp.last_match(1).strip
          directive_index = directives.length
          current_branch_index = directive_index
          directives << Howzit::Directive.new(
            type: :elsif,
            condition: condition,
            directive_type: 'elsif',
            line_number: line_num,
            conditional_path: conditional_stack[0..-2].dup
          )
          next
        elsif line =~ /^@else\s*$/i
          directive_index = directives.length
          current_branch_index = directive_index
          directives << Howzit::Directive.new(
            type: :else,
            directive_type: 'else',
            line_number: line_num,
            conditional_path: conditional_stack[0..-2].dup
          )
          next
        elsif line =~ /^@end\s*$/i && !conditional_stack.empty?
          # Closing a conditional block
          conditional_stack.pop
          current_branch_index = nil
          directives << Howzit::Directive.new(
            type: :end,
            directive_type: 'end',
            line_number: line_num,
            conditional_path: conditional_stack.dup
          )
          next
        end

        # Handle @log_level directive
        if line =~ /^@log_level\s*\(([^)]+)\)\s*$/i
          log_level = Regexp.last_match(1).strip
          conditional_path = conditional_stack.dup
          conditional_path << current_branch_index if current_branch_index
          directives << Howzit::Directive.new(
            type: :log_level,
            log_level_value: log_level,
            line_number: line_num,
            conditional_path: conditional_path
          )
          next
        end

        # Handle @set_var directive
        if line =~ /^@set_var\s*\(/i
          # Extract content between parentheses, handling nested parentheses
          paren_content = line.sub(/^@set_var\s*\(/i, '').sub(/\)\s*$/, '')
          # Split by first comma only - everything after first comma is the value
          if paren_content =~ /^([^,]+),\s*(.+)$/
            var_name = Regexp.last_match(1).strip
            var_value = Regexp.last_match(2).strip
            # Validate variable name: alphanumeric, dashes, underscores only
            if var_name =~ /^[A-Za-z0-9_-]+$/
              # Remove quotes from value if present (handles both single and double quotes)
              var_value = Regexp.last_match(1) if var_value =~ /^["'](.+)["']$/
              conditional_path = conditional_stack.dup
              conditional_path << current_branch_index if current_branch_index
              directives << Howzit::Directive.new(
                type: :set_var,
                var_name: var_name,
                var_value: var_value,
                line_number: line_num,
                conditional_path: conditional_path
              )
            end
          end
          next
        end

        # Handle task directives (@run, @include, etc.)
        unless line =~ /^@(?<cmd>include|run|copy|open|url)(?<optional>[!?]{1,2})?\((?<action>[^)]*?)\)(?<title>.*?)$/
          next
        end

        cmd = Regexp.last_match(:cmd)
        optional_str = Regexp.last_match(:optional) || ''
        action = Regexp.last_match(:action)
        title = Regexp.last_match(:title).strip

        optional, default = define_optional(optional_str)
        conditional_path = conditional_stack.dup
        # If we're inside an @elsif/@else branch, include it in the path
        conditional_path << current_branch_index if current_branch_index
        directives << Howzit::Directive.new(
          type: :task,
          content: {
            type: cmd.downcase.to_sym,
            action: action,
            title: title,
            arguments: nil
          },
          optional: optional,
          default: default,
          line_number: line_num,
          conditional_path: conditional_path
        )
      end

      directives
    end

    ##
    ## Run directives sequentially with conditional re-evaluation
    ##
    def run_sequential(output: [])
      # Initialize conditional state
      conditional_state = {} # { index => { evaluated: bool, result: bool, matched_chain: bool } }
      directive_index = 0
      current_log_level = nil # Track current log level set by @log_level directives

      # Initialize named_arguments with topic's named args (don't overwrite on each iteration)
      Howzit.named_arguments ||= {}
      Howzit.named_arguments.merge!(@named_args) if @named_args

      # Process directives sequentially
      while directive_index < @directives.length
        directive = @directives[directive_index]
        directive_index += 1

        # Update context for condition evaluation
        metadata = @metadata || Howzit.buildnote&.metadata
        context = { metadata: metadata }

        # Handle conditional directives
        if directive.conditional?
          case directive.type
          when :if, :unless
            # Evaluate condition
            result = ConditionEvaluator.evaluate(directive.condition, context)
            result = !result if directive.directive_type == 'unless'

            conditional_state[directive_index - 1] = {
              evaluated: true,
              result: result,
              matched_chain: result,
              condition: directive.condition,
              directive_type: directive.directive_type
            }

          when :elsif
            # Find the matching @if/@unless
            matching_if_index = find_matching_if_index(directive_index - 1)
            if matching_if_index && conditional_state[matching_if_index]
              # If previous branch matched, this is false
              if conditional_state[matching_if_index][:matched_chain]
                conditional_state[directive_index - 1] = {
                  evaluated: true,
                  result: false,
                  matched_chain: false,
                  condition: directive.condition,
                  directive_type: 'elsif',
                  parent_index: matching_if_index
                }
              else
                # Evaluate condition
                result = ConditionEvaluator.evaluate(directive.condition, context)
                conditional_state[directive_index - 1] = {
                  evaluated: true,
                  result: result,
                  matched_chain: result,
                  condition: directive.condition,
                  directive_type: 'elsif',
                  parent_index: matching_if_index
                }
                conditional_state[matching_if_index][:matched_chain] = true if result
              end
            end

          when :else
            # Find the matching @if/@unless
            matching_if_index = find_matching_if_index(directive_index - 1)
            if matching_if_index && conditional_state[matching_if_index]
              # If any previous branch matched, else is false
              if conditional_state[matching_if_index][:matched_chain]
                conditional_state[directive_index - 1] = {
                  evaluated: true,
                  result: false,
                  matched_chain: false,
                  directive_type: 'else',
                  parent_index: matching_if_index
                }
              else
                conditional_state[directive_index - 1] = {
                  evaluated: true,
                  result: true,
                  matched_chain: true,
                  directive_type: 'else',
                  parent_index: matching_if_index
                }
                conditional_state[matching_if_index][:matched_chain] = true
              end
            end

          when :end
            # End of conditional block - no action needed, state is managed by stack
          end
          next
        end

        # Handle @log_level directive (before task check)
        if directive.log_level?
          next unless directive_in_active_branch?(directive, conditional_state)

          current_log_level = directive.log_level_value
          next
        end

        # Handle @set_var directive (before task check)
        if directive.set_var?
          next unless directive_in_active_branch?(directive, conditional_state)

          # Set the variable in named_arguments
          Howzit.named_arguments ||= {}
          value = directive.var_value

          if value
            # Check for command substitution: backticks or $()
            if value =~ /^`(.+)`$/ || value =~ /^\$\((.+)\)$/
              command = Regexp.last_match(1).strip
              # Apply variable substitution to command before execution
              command = command.render_arguments
              # Execute command and capture output
              begin
                value = `#{command}`.strip
              rescue StandardError => e
                Howzit.console.warn("Error executing command in @set_var: #{e.message}")
                value = ''
              end
            else
              # Apply variable substitution to the value (in case it references other variables)
              value = value.render_arguments
            end
          end

          Howzit.named_arguments[directive.var_name] = value
          # Re-evaluate conditionals after setting variable
          re_evaluate_conditionals(conditional_state, directive_index - 1, context)
          next
        end

        # Handle task directives
        next unless directive.task?

        next unless directive_in_active_branch?(directive, conditional_state)

        # Convert directive to task
        task = directive.to_task(self, current_log_level: current_log_level)
        next unless task

        next if (task.optional || Howzit.options[:ask]) && !ask_task(task)

        run_output, total, success = task.run

        output.concat(run_output)
        record_task_result(task, total, success)
        if halted?
          # Tasks inside conditionals are omitted, since their conditions were never evaluated
          remaining = @directives[directive_index..].select { |d| d.task? && (d.conditional_path || []).empty? }
          log_skipped_tasks(remaining.filter_map { |d| d.to_task(self) })
          break
        end

        # Re-evaluate all open conditionals after task execution
        re_evaluate_conditionals(conditional_state, directive_index - 1, context)
      end

      output
    end

    ##
    ## Whether a directive nested under @if/@unless/@elsif/@else should run (same rules as tasks).
    ##
    def directive_in_active_branch?(directive, conditional_state)
      path = directive.conditional_path || []
      return true if path.empty?

      should_execute = true
      path_to_check = path.dup
      if path_to_check.length >= 2
        last_idx = path_to_check.last
        last_state = conditional_state[last_idx]
        if last_state && %w[elsif else].include?(last_state[:directive_type])
          parent_if_idx = path_to_check[-2]
          parent_if_state = conditional_state[parent_if_idx]
          if parent_if_state && %w[if unless].include?(parent_if_state[:directive_type])
            path_to_check.delete(parent_if_idx)
          end
        end
      end

      path_to_check.each do |cond_idx|
        cond_state = conditional_state[cond_idx]
        if cond_state.nil? || !cond_state[:evaluated] || !cond_state[:result]
          should_execute = false
          break
        end
      end

      should_execute
    end

    ##
    ## Find the index of the matching @if/@unless for an @elsif/@else/@end
    ##
    def find_matching_if_index(current_index)
      stack_depth = 0
      (current_index - 1).downto(0) do |i|
        dir = @directives[i]
        next unless dir.conditional?

        case dir.type
        when :end
          stack_depth += 1
        when :if, :unless
          return i if stack_depth.zero?

          stack_depth -= 1

        when :elsif, :else
          stack_depth -= 1 if stack_depth.positive?
        end
      end
      nil
    end

    ##
    ## Re-evaluate conditionals after a task runs (variables may have changed)
    ##
    def re_evaluate_conditionals(conditional_state, current_index, context)
      # Re-evaluate all conditionals that come after the current task
      # and before the next task
      (current_index + 1).upto(@directives.length - 1) do |i|
        dir = @directives[i]
        break if dir.task? # Stop at next task

        next unless dir.conditional?

        case dir.type
        when :if, :unless
          if conditional_state[i]
            # Re-evaluate
            result = ConditionEvaluator.evaluate(dir.condition, context)
            result = !result if dir.directive_type == 'unless'
            conditional_state[i][:result] = result
            conditional_state[i][:matched_chain] = result
          end
        when :elsif
          matching_if_index = find_matching_if_index(i)
          if matching_if_index && conditional_state[matching_if_index]
            parent_state = conditional_state[matching_if_index]
            if conditional_state[i]
              if parent_state[:matched_chain] && !conditional_state[i][:matched_chain]
                conditional_state[i][:result] = false
              else
                result = ConditionEvaluator.evaluate(dir.condition, context)
                conditional_state[i][:result] = result
                conditional_state[i][:matched_chain] = result
                parent_state[:matched_chain] = true if result
              end
            end
          end
        when :else
          matching_if_index = find_matching_if_index(i)
          if matching_if_index && conditional_state[matching_if_index]
            parent_state = conditional_state[matching_if_index]
            if conditional_state[i]
              if parent_state[:matched_chain]
                conditional_state[i][:result] = false
              else
                conditional_state[i][:result] = true
                conditional_state[i][:matched_chain] = true
                parent_state[:matched_chain] = true
              end
            end
          end
        when :end
          # No re-evaluation needed
        end
      end
    end
  end
end
