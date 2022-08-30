# frozen_string_literal: true

module Howzit
  # Task object
  class Task
    attr_reader :type, :title, :action, :parent, :optional, :default

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

      @type = attributes[:type] || :run
      @title = attributes[:title] || nil
      @action = attributes[:action].render_arguments || nil
      @parent = attributes[:parent] || nil
      @optional = optional
      @default = default
    end

    ##
    ## Inspect
    ##
    ## @return     [String] description
    ##
    def inspect
      %(<#Howzit::Task @type=:#{@type} @title="#{@title}" @block?=#{@action.split(/\n/).count > 1}>)
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

      res
    end

    ##
    ## Execute an include task
    ##
    ## @return     [Array] [[Array] output, [Integer] number of tasks executed]
    ##
    def run_include
      output = []
      matches = Howzit.buildnote.find_topic(@action)
      raise "Topic not found: #{@action}" if matches.empty?

      Howzit.console.info("#{@prefix}{by}Running tasks from {bw}#{matches[0].title}{x}".c)
      output.concat(matches[0].run(nested: true))
      Howzit.console.info("{by}End include: #{matches[0].tasks.count} tasks{x}".c)
      [output, matches[0].tasks.count]
    end

    ##
    ## Execute a run task
    ##
    def run_run
      title = Howzit.options[:show_all_code] ? @action : @title
      Howzit.console.info("#{@prefix}{bg}Running {bw}#{title}{x}".c)
      return system(@action)
    end

    ##
    ## Execute a copy task
    ##
    def run_copy
      title = Howzit.options[:show_all_code] ? @action : @title
      Howzit.console.info("#{@prefix}{bg}Copied {bw}#{title}{bg} to clipboard{x}".c)
      Util.os_copy(@action)
      return true
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
              end
            end

      [output, tasks, res]
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
