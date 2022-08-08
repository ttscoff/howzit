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
      Howzit.console.info "{bg}Running block {bw}#{@title}{x}".c if Howzit.options[:log_level] < 2
      block = @action
      script = Tempfile.new('howzit_script')
      begin
        script.write(block)
        script.close
        File.chmod(0o777, script.path)
        system(%(/bin/sh -c "#{script.path}"))
      ensure
        script.close
        script.unlink
      end
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

      Howzit.console.info("{by}Running tasks from {bw}#{matches[0].title}{x}".c)
      output.concat(matches[0].run(nested: true))
      Howzit.console.info("{by}End include: #{matches[0].tasks.count} tasks{x}".c)
      [output, matches[0].tasks.count]
    end

    ##
    ## Execute a run task
    ##
    def run_run
      title = Howzit.options[:show_all_code] ? @action : @title
      Howzit.console.info("{bg}Running {bw}#{title}{x}".c)
      system(@action)
    end

    ##
    ## Execute a copy task
    ##
    def run_copy
      title = Howzit.options[:show_all_code] ? @action : @title
      Howzit.console.info("{bg}Copied {bw}#{title}{bg} to clipboard{x}".c)
      os_copy(@action)
    end

    ##
    ## Platform-agnostic copy-to-clipboard
    ##
    ## @param      string  [String] The string to copy
    ##
    def os_copy(string)
      os = RbConfig::CONFIG['target_os']
      out = "{bg}Copying {bw}#{string}".c
      case os
      when /darwin.*/i
        Howzit.console.debug("#{out} (macOS){x}".c)
        `echo #{Shellwords.escape(string)}'\\c'|pbcopy`
      when /mingw|mswin/i
        Howzit.console.debug("#{out} (Windows){x}".c)
        `echo #{Shellwords.escape(string)} | clip`
      else
        if 'xsel'.available?
          Howzit.console.debug("#{out} (Linux, xsel){x}".c)
          `echo #{Shellwords.escape(string)}'\\c'|xsel -i`
        elsif 'xclip'.available?
          Howzit.console.debug("#{out} (Linux, xclip){x}".c)
          `echo #{Shellwords.escape(string)}'\\c'|xclip -i`
        else
          Howzit.console.debug(out)
          Howzit.console.warn('Unable to determine executable for clipboard.')
        end
      end
    end

    ##
    ## Platform-agnostic open command
    ##
    ## @param      command  [String] The command
    ##
    def os_open(command)
      os = RbConfig::CONFIG['target_os']
      out = "{bg}Opening {bw}#{command}".c
      case os
      when /darwin.*/i
        Howzit.console.debug "#{out} (macOS){x}".c if Howzit.options[:log_level] < 2
        `open #{Shellwords.escape(command)}`
      when /mingw|mswin/i
        Howzit.console.debug "#{out} (Windows){x}".c if Howzit.options[:log_level] < 2
        `start #{Shellwords.escape(command)}`
      else
        if 'xdg-open'.available?
          Howzit.console.debug "#{out} (Linux){x}".c if Howzit.options[:log_level] < 2
          `xdg-open #{Shellwords.escape(command)}`
        else
          Howzit.console.debug out if Howzit.options[:log_level] < 2
          Howzit.console.debug 'Unable to determine executable for `open`.'
        end
      end
    end

    ##
    ## Execute the task
    ##
    def run
      output = []
      tasks = 1
      if @type == :block
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
          os_open(@action)
        end
      end

      [output, tasks]
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
