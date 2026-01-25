# frozen_string_literal: true

require 'English'

module Howzit
  # Task object
  class Task
    attr_reader :type, :title, :action, :arguments, :parent, :optional, :default, :last_status, :log_level, :source_file

    ##
    ## Initialize a Task object
    ##
    ## @param      attributes  [Hash] the task attributes
    ## @param      optional    [Boolean] Task requires
    ##                         confirmation
    ## @param      default     [Boolean] Default response
    ##                         for confirmation dialog
    ##
    ## @option attributes :type [Symbol] task type (:block, :run, :include, :copy)
    ## @option attributes :title [String] task title
    ## @option attributes :action [String] task action
    ## @option attributes :parent [String] title of nested (included) topic origin
    ## @option attributes :log_level [String] log level for this task (debug, info, warn, error)
    ## @option attributes :source_file [String] path to the build note file this task came from
    def initialize(attributes, optional: false, default: true)
      @prefix = "{bw}\u{25B7}\u{25B7} {x}"
      # arrow = "{bw}\u{279F}{x}"
      @arguments = attributes[:arguments] || []

      @type = attributes[:type] || :run
      @title = attributes[:title]&.to_s
      @parent = attributes[:parent] || nil

      @action = attributes[:action].render_arguments || nil
      @log_level = attributes[:log_level]
      # Get source_file from parent topic if available, or from attributes
      parent_obj = attributes[:parent]
      @source_file = attributes[:source_file] || parent_obj&.source_file

      @optional = optional
      @default = default
      @last_status = nil
    end

    ##
    ## Inspect
    ##
    ## @return     [String] description
    ##
    def inspect
      %(<#Howzit::Task @type=:#{@type} @title="#{@title}" @action="#{@action}" @arguments=#{@arguments} @block?=#{@action.split(/\n/).count > 1}>)
    end

    ##
    ## Output string representation
    ##
    ## @return     [String] string representation of the object.
    ##
    def to_s
      @title
    end

    ##
    ## Execute a block type
    ##
    def run_block
      Howzit.console.info "#{@prefix}{bg}Running block {bw}#{@title}{x}".c if Howzit.options[:log_level] < 2
      block = @action
      # Apply variable substitution to block content at execution time
      # (variables from previous run blocks are now available)
      block = block.render_arguments if block && !block.empty?
      script = Tempfile.new('howzit_script')
      comm_file = ScriptComm.setup
      old_log_level = apply_log_level

      # Get execution directory from source_file
      # Only change directory in stack mode, and only if source_file is from a parent directory (not a template)
      exec_dir = nil
      if @source_file && Howzit.options[:stack]
        expanded_source = File.expand_path(@source_file)
        source_dir = File.dirname(expanded_source)

        # Check if this is a template file - don't change directory for templates
        is_template = false
        if Howzit.config.respond_to?(:template_folder) && Howzit.config.template_folder
          template_folder = File.expand_path(Howzit.config.template_folder)
          is_template = expanded_source.start_with?(template_folder)
        end

        # Only change directory if not a template
        exec_dir = source_dir unless is_template
      end
      original_dir = Dir.pwd

      begin
        # Change to source file directory if available and different from current
        # Only change if the directory exists and is actually different
        if exec_dir && Dir.exist?(exec_dir)
          expanded_exec_dir = File.expand_path(exec_dir)
          expanded_original = File.expand_path(original_dir)
          Dir.chdir(expanded_exec_dir) if expanded_exec_dir != expanded_original
        end

        # Ensure support directory exists and install helpers
        ScriptSupport.ensure_support_dir
        ENV['HOWZIT_SUPPORT_DIR'] = ScriptSupport.support_dir

        # Inject helper script loading
        modified_block, interpreter = ScriptSupport.inject_helper(block)

        script.write(modified_block)
        script.close
        File.chmod(0o755, script.path)

        # Use appropriate interpreter command
        cmd = ScriptSupport.execution_command_for(script.path, interpreter)
        # If interpreter is nil, execute directly (will respect hashbang)
        res = if interpreter.nil?
                system(script.path)
              else
                system(cmd)
              end
      ensure
        # Restore original directory
        if exec_dir && Dir.exist?(exec_dir)
          expanded_exec_dir = File.expand_path(exec_dir)
          expanded_original = File.expand_path(original_dir)
          Dir.chdir(expanded_original) if expanded_exec_dir != expanded_original
        end
        restore_log_level(old_log_level) if old_log_level
        script.close
        script.unlink
        # Process script communication
        ScriptComm.apply(comm_file) if comm_file
      end

      update_last_status(res ? 0 : 1)
      res
    end

    ##
    ## Execute an include task
    ##
    ## @return     [Array] [[Array] output, [Integer] number of tasks executed]
    ##
    def run_include
      output = []
      action = @action

      matches = Howzit.buildnote.find_topic(action)
      raise "Topic not found: #{action}" if matches.empty?

      Howzit.console.info("#{@prefix}{by}Running tasks from {bw}#{matches[0].title}{x}".c)
      output.concat(matches[0].run(nested: true))
      Howzit.console.info("{by}End include: #{matches[0].tasks.count} tasks{x}".c)
      @last_status = nil
      [output, matches[0].tasks.count]
    end

    ##
    ## Apply log level for this task
    ##
    def apply_log_level
      return unless @log_level

      level_map = {
        'debug' => 0,
        'info' => 1,
        'warn' => 2,
        'warning' => 2,
        'error' => 3
      }
      level_value = level_map[@log_level.downcase] || @log_level.to_i
      old_level = Howzit.options[:log_level]
      Howzit.options[:log_level] = level_value
      Howzit.console.log_level = level_value
      ENV['HOWZIT_LOG_LEVEL'] = @log_level.downcase
      old_level
    end

    ##
    ## Restore log level after task execution
    ##
    def restore_log_level(old_level)
      return unless @log_level

      Howzit.options[:log_level] = old_level
      Howzit.console.log_level = old_level
      ENV.delete('HOWZIT_LOG_LEVEL')
    end

    ##
    ## Execute a run task
    ##
    def run_run
      # If a title was explicitly provided (different from action), always use it
      # Otherwise, use action (or respect show_all_code if no title)
      display_title = if @title && !@title.empty? && @title != @action
                        # Title was explicitly provided, use it
                        @title
                      elsif Howzit.options[:show_all_code]
                        # No explicit title, show code if requested
                        @action
                      else
                        # No explicit title, use title if available (might be same as action), otherwise action
                        @title && !@title.empty? ? @title : @action
                      end
      Howzit.console.info("#{@prefix}{bg}Running {bw}#{display_title}{x}".c)
      ENV['HOWZIT_SCRIPTS'] = File.expand_path('~/.config/howzit/scripts')
      comm_file = ScriptComm.setup
      old_log_level = apply_log_level

      # Get execution directory from source_file
      # Only change directory in stack mode, and only if source_file is from a parent directory (not a template)
      exec_dir = nil
      if @source_file && Howzit.options[:stack]
        expanded_source = File.expand_path(@source_file)
        source_dir = File.dirname(expanded_source)

        # Check if this is a template file - don't change directory for templates
        is_template = false
        if Howzit.config.respond_to?(:template_folder) && Howzit.config.template_folder
          template_folder = File.expand_path(Howzit.config.template_folder)
          is_template = expanded_source.start_with?(template_folder)
        end

        # Only change directory if not a template
        exec_dir = source_dir unless is_template
      end
      original_dir = Dir.pwd

      begin
        # Change to source file directory if available and different from current
        # Only change if the directory exists and is actually different
        if exec_dir && Dir.exist?(exec_dir)
          expanded_exec_dir = File.expand_path(exec_dir)
          expanded_original = File.expand_path(original_dir)
          Dir.chdir(expanded_exec_dir) if expanded_exec_dir != expanded_original
        end

        res = system(@action)
      ensure
        # Restore original directory
        if exec_dir && Dir.exist?(exec_dir)
          expanded_exec_dir = File.expand_path(exec_dir)
          expanded_original = File.expand_path(original_dir)
          Dir.chdir(expanded_original) if expanded_exec_dir != expanded_original
        end
        restore_log_level(old_log_level) if old_log_level
        # Process script communication
        ScriptComm.apply(comm_file) if comm_file
      end
      update_last_status(res ? 0 : 1)
      res
    end

    ##
    ## Execute a copy task
    ##
    def run_copy
      # If a title was explicitly provided (different from action), always use it
      # Otherwise, use action (or respect show_all_code if no title)
      display_title = if @title && !@title.empty? && @title != @action
                        # Title was explicitly provided, use it
                        @title
                      elsif Howzit.options[:show_all_code]
                        # No explicit title, show code if requested
                        @action
                      else
                        # No explicit title, use title if available (might be same as action), otherwise action
                        @title && !@title.empty? ? @title : @action
                      end
      Howzit.console.info("#{@prefix}{bg}Copied {bw}#{display_title}{bg} to clipboard{x}".c)
      Util.os_copy(@action)
      @last_status = 0
      true
    end

    ##
    ## Execute the task
    ##
    def run
      output = []
      tasks = 1
      res = if @type == :block
              run_block
            else
              case @type
              when :include
                output, tasks = run_include
              when :run
                run_run
              when :copy
                run_copy
              when :open
                Util.os_open(@action)
                @last_status = 0
                true
              end
            end

      [output, tasks, res]
    end

    def update_last_status(default = nil)
      status = if defined?($CHILD_STATUS) && $CHILD_STATUS
                 $CHILD_STATUS.exitstatus
               else
                 default
               end
      @last_status = status
    end

    ##
    ## Output terminal-formatted list item
    ##
    ## @return     [String] List representation of the object.
    ##
    def to_list
      # Highlight variables in title if parent topic has the method
      display_title = if @parent.respond_to?(:highlight_variables)
                        @parent.highlight_variables(@title.preserve_escapes)
                      else
                        @title.preserve_escapes
                      end
      "    * #{@type}: #{display_title}"
    end
  end
end
