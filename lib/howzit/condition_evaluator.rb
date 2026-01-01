# frozen_string_literal: true

require 'English'

module Howzit
  # Condition Evaluator module
  # Handles evaluation of @if/@unless conditions
  module ConditionEvaluator
    class << self
      ##
      ## Evaluate a condition expression
      ##
      ## @param      condition  [String] The condition to evaluate
      ## @param      context    [Hash] Context with metadata, arguments, etc.
      ##
      ## @return     [Boolean] Result of condition evaluation
      ##
      def evaluate(condition, context = {})
        condition = condition.strip

        # Handle negation with 'not' or '!'
        negated = false
        if condition =~ /^(not\s+|!)/
          negated = true
          condition = condition.sub(/^(not\s+|!)/, '').strip
        end

        result = evaluate_condition(condition, context)
        negated ? !result : result
      end

      private

      ##
      ## Evaluate a single condition (without negation)
      ##
      def evaluate_condition(condition, context)
        # Handle special conditions FIRST to avoid false matches with comparison patterns
        # Check file contents before other patterns since it has arguments and operators
        if condition =~ /^file\s+contents\s+(.+?)\s+(\*\*=|\*=|\^=|\$=|==|!=|=~)\s*(.+)$/i
          return evaluate_file_contents(condition, context)
        # Check file/dir/topic exists before other patterns since they have arguments
        elsif condition =~ /^(file\s+exists|dir\s+exists|topic\s+exists)\s+(.+)$/i
          return evaluate_special(condition, context)
        elsif condition =~ /^(git\s+dirty|git\s+clean)$/i
          return evaluate_special(condition, context)
        end

        # Handle =~ regex comparisons separately (before string == to avoid conflicts)
        if (match = condition.match(%r{^(.+?)\s*=~\s*/(.+)/$}))
          left = match[1].strip
          pattern = match[2].strip

          left_val = get_value(left, context)
          return false if left_val.nil?

          !!(left_val.to_s =~ /#{pattern}/)
        # Handle comparisons with ==, !=, >, >=, <, <=
        # Determine if numeric or string comparison based on values
        elsif (match = condition.match(/^(.+?)\s*(==|!=|>=|<=|>|<)\s*(.+)$/))
          left = match[1].strip
          operator = match[2]
          right = match[3].strip

          left_val = get_value(left, context)
          # If get_value returned nil, try using the original string as a literal
          left_val = left if left_val.nil? && numeric_value(left)
          right_val = get_value(right, context)
          # If get_value returned nil, try using the original string as a literal
          right_val = right if right_val.nil? && numeric_value(right)

          # Try to convert to numbers
          left_num = numeric_value(left_val)
          right_num = numeric_value(right_val)

          # If both are numeric, use numeric comparison
          if left_num && right_num
            case operator
            when '=='
              left_num == right_num
            when '!='
              left_num != right_num
            when '>'
              left_num > right_num
            when '>='
              left_num >= right_num
            when '<'
              left_num < right_num
            when '<='
              left_num <= right_num
            else
              false
            end
          # Otherwise use string comparison for == and !=, or return false for others
          else
            case operator
            when '=='
              # Handle nil comparisons
              left_val.nil? == right_val.nil? && (left_val.nil? || left_val.to_s == right_val.to_s)
            when '!='
              left_val.nil? != right_val.nil? || (!left_val.nil? && !right_val.nil? && left_val.to_s != right_val.to_s)
            else
              # For >, >=, <, <=, return false if not numeric
              false
            end
          end
        # Handle string-only comparisons: **= (fuzzy match), *= (contains), ^= (starts with), $= (ends with)
        # Note: **= must come before *= in the regex to avoid matching *= first
        elsif (match = condition.match(/^(.+?)\s*(\*\*=|\*=|\^=|\$=)\s*(.+)$/))
          left = match[1].strip
          operator = match[2]
          right = match[3].strip

          left_val = get_value(left, context)
          right_val = get_value(right, context)
          # If right side is nil (variable not found), treat it as a literal string
          right_val = right if right_val.nil?

          return false if left_val.nil? || right_val.nil?

          case operator
          when '*='
            left_val.to_s.include?(right_val.to_s)
          when '^='
            left_val.to_s.start_with?(right_val.to_s)
          when '$='
            left_val.to_s.end_with?(right_val.to_s)
          when '**='
            # Fuzzy match: split search string into chars and join with .*? for regex
            pattern = "^.*?#{right_val.to_s.split('').map { |c| Regexp.escape(c) }.join('.*?')}.*?$"
            !!(left_val.to_s =~ /#{pattern}/)
          else
            false
          end
        # Simple existence check (just a variable name)
        else
          val = get_value(condition, context)
          !val.nil? && val.to_s != ''
        end
      end

      ##
      ## Get value from various sources
      ##
      def get_value(expr, context)
        expr = expr.strip

        # Remove quotes if present
        return Regexp.last_match(1) if expr =~ /^["'](.+)["']$/

        # Remove ${} wrapper if present (for consistency with variable substitution syntax)
        expr = Regexp.last_match(1) if expr =~ /^\$\{(.+)\}$/

        # Check positional arguments
        if expr =~ /^\$(\d+)$/
          idx = Regexp.last_match(1).to_i - 1
          return Howzit.arguments[idx] if Howzit.arguments && Howzit.arguments[idx]
        end

        # Check named arguments
        return Howzit.named_arguments[expr.to_sym] if Howzit.named_arguments&.key?(expr.to_sym)
        return Howzit.named_arguments[expr] if Howzit.named_arguments&.key?(expr)

        # Check metadata (from context only, to avoid circular dependencies)
        metadata = context[:metadata]
        return metadata[expr] if metadata&.key?(expr)
        return metadata[expr.downcase] if metadata&.key?(expr.downcase)

        # Check environment variables
        return ENV[expr] if ENV.key?(expr)
        return ENV[expr.upcase] if ENV.key?(expr.upcase)

        # Check for special values: cwd, working directory
        return Dir.pwd if expr =~ /^(cwd|working\s+directory)$/i

        # Return nil if nothing matched (variable is undefined)
        nil
      end

      ##
      ## Convert value to numeric if possible
      ##
      def numeric_value(val)
        return val if val.is_a?(Numeric)

        str = val.to_s.strip
        return nil if str.empty?

        # Try integer first
        return str.to_i if str =~ /^-?\d+$/

        # Try float
        return str.to_f if str =~ /^-?\d+\.\d+$/

        nil
      end

      ##
      ## Evaluate special conditions
      ##
      def evaluate_special(condition, context)
        condition = condition.downcase.strip

        if condition =~ /^git\s+dirty$/i
          git_dirty?
        elsif condition =~ /^git\s+clean$/i
          !git_dirty?
        elsif (match = condition.match(/^file\s+exists\s+(.+)$/i))
          file = match[1].strip
          # get_value returns nil if not found, so use original path if nil
          file_val = get_value(file, context)
          file_path = file_val.nil? ? file : file_val.to_s
          File.exist?(file_path) && !File.directory?(file_path)
        elsif (match = condition.match(/^dir\s+exists\s+(.+)$/i))
          dir = match[1].strip
          dir_val = get_value(dir, context)
          dir_path = dir_val.nil? ? dir : dir_val.to_s
          File.directory?(dir_path)
        elsif (match = condition.match(/^topic\s+exists\s+(.+)$/i))
          topic_name = match[1].strip
          topic_name = get_value(topic_name, context).to_s
          find_topic(topic_name)
        else
          false
        end
      end

      ##
      ## Check if git repository is dirty
      ##
      def git_dirty?
        return false unless `which git`.strip != ''

        Dir.chdir(Dir.pwd) do
          `git diff --quiet 2>/dev/null`
          $CHILD_STATUS.exitstatus != 0
        end
      end

      ##
      ## Check if topic exists in buildnote
      ##
      def find_topic(topic_name)
        return false unless Howzit.buildnote

        matches = Howzit.buildnote.find_topic(topic_name)
        !matches.empty?
      end

      ##
      ## Evaluate file contents condition
      ## Reads file and performs string comparison
      ##
      def evaluate_file_contents(condition, context)
        match = condition.match(/^file\s+contents\s+(.+?)\s+(\*\*=|\*=|\^=|\$=|==|!=|=~)\s*(.+)$/i)
        return false unless match

        file_path = match[1].strip
        operator = match[2]
        search_value = match[3].strip

        # Resolve file path (could be a variable)
        file_path_val = get_value(file_path, context)
        file_path = file_path_val.nil? ? file_path : file_path_val.to_s

        # Resolve search value (could be a variable)
        search_val = get_value(search_value, context)
        search_val = search_val.nil? ? search_value : search_val.to_s

        # Read file contents
        return false unless File.exist?(file_path) && !File.directory?(file_path)

        begin
          file_contents = File.read(file_path).strip
        rescue StandardError
          return false
        end

        # Perform comparison based on operator
        case operator
        when '=='
          file_contents == search_val.to_s
        when '!='
          file_contents != search_val.to_s
        when '*='
          file_contents.include?(search_val.to_s)
        when '^='
          file_contents.start_with?(search_val.to_s)
        when '$='
          file_contents.end_with?(search_val.to_s)
        when '**='
          # Fuzzy match: split search string into chars and join with .*? for regex
          pattern = "^.*?#{search_val.to_s.split('').map { |c| Regexp.escape(c) }.join('.*?')}.*?$"
          !!(file_contents =~ /#{pattern}/)
        when '=~'
          # Regex match - search_value should be a regex pattern
          pattern = search_val.to_s
          # Remove leading/trailing slashes if present
          pattern = pattern[1..-2] if pattern.start_with?('/') && pattern.end_with?('/')
          !!(file_contents =~ /#{pattern}/)
        else
          false
        end
      end
    end
  end
end
