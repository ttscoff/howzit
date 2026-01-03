# frozen_string_literal: true

module Howzit
  # Topic Class
  class Topic
    attr_writer :parent

    attr_accessor :content

    attr_reader :title, :tasks, :prereqs, :postreqs, :results, :named_args, :directives

    ##
    ## Initialize a topic object
    ##
    ## @param      title    [String] The topic title
    ## @param      content  [String] The raw topic content
    ## @param      metadata [Hash] Optional metadata hash
    ##
    def initialize(title, content, metadata = nil)
      @title = title
      @content = content
      @parent = nil
      @nest_level = 0
      @named_args = {}
      @metadata = metadata
      arguments

      @directives = parse_directives_with_conditionals
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

        @named_args[arg_name] = if Howzit.arguments && Howzit.arguments.count >= idx + 1
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

      # Use sequential processing if we have directives with conditionals
      if @directives && @directives.any?(&:conditional?)
        return run_sequential(nested: nested, output: output, cols: cols)
      end

      # Fall back to old behavior for backward compatibility
      if @tasks.count.positive?
        unless @prereqs.empty?
          begin
            puts TTY::Box.frame("{by}#{@prereqs.join("\n\n").wrap(cols - 4)}{x}".c, width: cols)
          rescue Errno::EPIPE
            # Pipe closed, ignore
          end
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

          log_task_result(task, success)
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

      output.push(@results[:message]) if Howzit.options[:log_level] < 2 && !nested && !Howzit.options[:run]

      unless @postreqs.empty?
        begin
          puts TTY::Box.frame("{bw}#{@postreqs.join("\n\n").wrap(cols - 4)}{x}".c, width: cols)
        rescue Errno::EPIPE
          # Pipe closed, ignore
        end
      end

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
        output.push(@title.format_header)
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
      Howzit.named_arguments = @named_args
      case cmd
      when /include/i
        if title =~ /\[(.*?)\] *$/
          args = Regexp.last_match(1).split(/ *, */).map(&:render_arguments)
          Howzit.arguments = args
          arguments
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

    ##
    ## Collect all directives in the topic content
    ##
    ## @return     [Array] array of Task objects
    ##
    def log_task_result(task, success)
      return unless Howzit.options[:run]
      return if task.type == :include

      Howzit.run_log ||= []

      title = (task.title || '').strip
      if title.empty?
        action = (task.action || '').strip
        title = action.split(/\n/).first.to_s.strip
      end
      title = task.type.to_s.capitalize if title.nil? || title.empty?

      Howzit.run_log << {
        topic: @title,
        task: title,
        success: success ? true : false,
        exit_status: task.last_status
      }
    end

    def gather_tasks
      runnable = []
      # Process conditional blocks first
      # Set named_arguments before processing so conditions can access them
      Howzit.named_arguments = @named_args
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
        Howzit.named_arguments = @named_args

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
          directives << Howzit::Directive.new(
            type: :elsif,
            condition: condition,
            directive_type: 'elsif',
            line_number: line_num,
            conditional_path: conditional_stack[0..-2].dup
          )
          next
        elsif line =~ /^@else\s*$/i
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
          directives << Howzit::Directive.new(
            type: :log_level,
            log_level_value: log_level,
            line_number: line_num,
            conditional_path: conditional_path
          )
          next
        end

        # Handle task directives (@run, @include, etc.)
        if line =~ /^@(?<cmd>include|run|copy|open|url)(?<optional>[!?]{1,2})?\((?<action>[^)]*?)\)(?<title>.*?)$/
          cmd = Regexp.last_match(:cmd)
          optional_str = Regexp.last_match(:optional) || ''
          action = Regexp.last_match(:action)
          title = Regexp.last_match(:title).strip

          optional, default = define_optional(optional_str)
          conditional_path = conditional_stack.dup
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
      end

      directives
    end

    ##
    ## Run directives sequentially with conditional re-evaluation
    ##
    def run_sequential(nested: false, output: [], cols: 80)
      # Initialize conditional state
      conditional_state = {} # { index => { evaluated: bool, result: bool, matched_chain: bool } }
      directive_index = 0
      current_log_level = nil # Track current log level set by @log_level directives

      unless @prereqs.empty?
        begin
          puts TTY::Box.frame("{by}#{@prereqs.join("\n\n").wrap(cols - 4)}{x}".c, width: cols)
        rescue Errno::EPIPE
          # Pipe closed, ignore
        end
        res = Prompt.yn('Have the above prerequisites been met?', default: true)
        Process.exit 1 unless res
      end

      # Process directives sequentially
      while directive_index < @directives.length
        directive = @directives[directive_index]
        directive_index += 1

        # Update context for condition evaluation
        metadata = @metadata || Howzit.buildnote&.metadata
        Howzit.named_arguments = @named_args
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

        # Handle task directives
        if directive.task?
          # Check if all parent conditionals are true
          should_execute = true
          directive.conditional_path.each do |cond_idx|
            cond_state = conditional_state[cond_idx]
            if cond_state.nil? || !cond_state[:evaluated] || !cond_state[:result]
              should_execute = false
              break
            end
          end

          next unless should_execute

          # Handle @log_level directive
          if directive.log_level?
            current_log_level = directive.log_level_value
            next
          end

          # Convert directive to task
          task = directive.to_task(self, current_log_level: current_log_level)
          next unless task

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

          log_task_result(task, success)

          # Re-evaluate all open conditionals after task execution
          re_evaluate_conditionals(conditional_state, directive_index - 1, context)
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

      output.push(@results[:message]) if Howzit.options[:log_level] < 2 && !nested && !Howzit.options[:run]

      unless @postreqs.empty?
        begin
          puts TTY::Box.frame("{bw}#{@postreqs.join("\n\n").wrap(cols - 4)}{x}".c, width: cols)
        rescue Errno::EPIPE
          # Pipe closed, ignore
        end
      end

      output
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
          if stack_depth.zero?
            return i
          else
            stack_depth -= 1
          end
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
