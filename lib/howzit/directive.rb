# frozen_string_literal: true

require 'shellwords'

module Howzit
  # Directive class
  # Represents a parsed directive from topic content (tasks, conditionals, etc.)
  class Directive
    attr_reader :type, :content, :condition, :directive_type, :optional, :default, :line_number, :conditional_path,
                :log_level_value, :var_name, :var_value

    ##
    ## Initialize a Directive
    ##
    ## @param      type            [Symbol] :task, :if, :unless, :elsif, :else, :end, :log_level
    ## @param      content         [String] The directive content (action, block, etc.)
    ## @param      condition       [String, nil] Condition string for conditionals
    ## @param      directive_type  [String, nil] 'if', 'unless', 'elsif', 'else' for conditionals
    ## @param      optional        [Boolean] Whether task requires confirmation
    ## @param      default         [Boolean] Default response for confirmation
    ## @param      line_number     [Integer] Line number in original content
    ## @param      conditional_path [Array] Array of conditional indices this directive is nested in
    ## @param      log_level_value [String, nil] Log level value for @log_level directives
    ## @param      var_name        [String, nil] Variable name for @set_var directives
    ## @param      var_value       [String, nil] Variable value for @set_var directives
    ##
    def initialize(type:, content: nil, condition: nil, directive_type: nil, optional: false, default: true,
                   line_number: nil, conditional_path: [], log_level_value: nil, var_name: nil, var_value: nil)
      @type = type
      @content = content
      @condition = condition
      @directive_type = directive_type
      @optional = optional
      @default = default
      @line_number = line_number
      @conditional_path = conditional_path || []
      @log_level_value = log_level_value
      @var_name = var_name
      @var_value = var_value
    end

    ##
    ## Is this a conditional directive?
    ##
    def conditional?
      %i[if unless elsif else end].include?(@type)
    end

    ##
    ## Is this a task directive?
    ##
    def task?
      @type == :task
    end

    ##
    ## Is this a log_level directive?
    ##
    def log_level?
      @type == :log_level
    end

    ##
    ## Is this a set_var directive?
    ##
    def set_var?
      @type == :set_var
    end

    ##
    ## Convert directive to a Task object (only works for task directives)
    ##
    ## @param      parent        [Topic] The parent topic
    ## @param      current_log_level [String, nil] Current log level to apply to task
    ##
    ## @return     [Task] Task object
    ##
    def to_task(parent, current_log_level: nil)
      return nil unless task?

      task_data = @content.dup
      task_type = task_data[:type]

      # Apply current log level if set and task doesn't have its own
      task_data[:log_level] = current_log_level if current_log_level && !task_data[:log_level]

      # Set named_arguments before processing titles for variable substitution
      Howzit.named_arguments = parent.named_args

      case task_type
      when :block
        # Block tasks are already properly formatted
        task_data[:parent] = parent
        Howzit::Task.new(task_data, optional: @optional, default: @default)
      when :run
        # Run tasks need title rendering (similar to define_task_args)
        title = task_data[:title]
        title = title.render_arguments if title && !title.empty?
        task_data[:title] = title
        task_data[:parent] = parent
        Howzit::Task.new(task_data, optional: @optional, default: @default)
      when :copy
        # Copy tasks need title rendering and action escaping
        title = task_data[:title]
        title = title.render_arguments if title && !title.empty?
        task_data[:title] = title
        task_data[:action] = Shellwords.escape(task_data[:action])
        task_data[:parent] = parent
        Howzit::Task.new(task_data, optional: @optional, default: @default)
      when :open
        # Open tasks need title rendering
        title = task_data[:title]
        title = title.render_arguments if title && !title.empty?
        task_data[:title] = title
        task_data[:parent] = parent
        Howzit::Task.new(task_data, optional: @optional, default: @default)
      when :include
        # Include tasks need special handling (title processing, arguments, etc.)
        title = task_data[:title]
        if title =~ /\[(.*?)\] *$/
          args = Regexp.last_match(1).split(/ *, */).map(&:render_arguments)
          Howzit.arguments = args
          parent.arguments
          title.sub!(/ *\[.*?\] *$/, '')
        end
        title = title.render_arguments if title && !title.empty?
        task_data[:title] = title
        task_data[:parent] = parent
        task_data[:arguments] = Howzit.named_arguments
        Howzit::Task.new(task_data, optional: @optional, default: @default)
      else
        task_data[:parent] = parent
        Howzit::Task.new(task_data, optional: @optional, default: @default)
      end
    end
  end
end
