# frozen_string_literal: true

require 'English'

module Howzit
  # Task object
  class Task
    attr_reader :type, :title, :action, :arguments, :parent, :optional, :default, :last_status

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
    def initialize(attributes, optional: false, default: true)
      @prefix = "{bw}\u{25B7}\u{25B7} {x}"
      # arrow = "{bw}\u{279F}{x}"
      @arguments = attributes[:arguments] || []

      @type = attributes[:type] || :run
      @title = attributes[:title].nil? ? nil : attributes[:title].to_s
      @parent = attributes[:parent] || nil

      @action = attributes[:action].render_arguments || nil

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
      script = Tempfile.new('howzit_script')
      begin
        script.write(block)
        script.close
        File.chmod(0o777, script.path)
        res = system(%(/bin/sh -c "#{script.path}"))
      ensure
        script.close
        script.unlink
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
      res = system(@action)
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
      "    * #{@type}: #{@title.preserve_escapes}"
    end
  end
end
