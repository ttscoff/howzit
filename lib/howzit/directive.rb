# frozen_string_literal: true

module Howzit
  # Directive class
  # Represents a parsed directive from topic content (tasks, conditionals, etc.)
  class Directive
    attr_reader :type, :content, :condition, :directive_type, :optional, :default, :line_number, :conditional_path,
                :log_level_value

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
    ##
    def initialize(type:, content: nil, condition: nil, directive_type: nil, optional: false, default: true,
                   line_number: nil, conditional_path: [], log_level_value: nil)
      @type = type
      @content = content
      @condition = condition
      @directive_type = directive_type
      @optional = optional
      @default = default
      @line_number = line_number
      @conditional_path = conditional_path || []
      @log_level_value = log_level_value
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

      case task_type
      when :block
        # Block tasks are already properly formatted
        task_data[:parent] = parent
        Howzit::Task.new(task_data, optional: @optional, default: @default)
      when :run, :copy, :open
        # Simple tasks - use define_task_args equivalent logic
        task_data[:parent] = parent
        Howzit::Task.new(task_data, optional: @optional, default: @default)
      when :include
        # Include tasks need special handling
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
