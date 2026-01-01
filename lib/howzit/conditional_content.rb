# frozen_string_literal: true

module Howzit
  # Conditional Content processor
  # Handles @if/@unless/@end blocks in topic content
  module ConditionalContent
    class << self
      ##
      ## Process conditional blocks in content
      ##
      ## @param      content  [String] The content to process
      ## @param      context  [Hash] Context for condition evaluation
      ##
      ## @return     [String] Content with conditional blocks processed
      ##
      def process(content, context = {})
        lines = content.split(/\n/)
        output = []
        condition_stack = []
        # Track if any condition in the current chain has been true
        # This is used for @elsif and @else to know if a previous branch matched
        chain_matched_stack = []

        lines.each do |line|
          # Check for @if or @unless
          if line =~ /^@(if|unless)\s+(.+)$/i
            directive = Regexp.last_match(1).downcase
            condition = Regexp.last_match(2).strip

            # Evaluate condition
            result = ConditionEvaluator.evaluate(condition, context)
            # For @unless, negate the result
            result = !result if directive == 'unless'

            condition_stack << result
            chain_matched_stack << result

            # Don't include the @if/@unless line itself
            next
          end

          # Check for @elsif
          if line =~ /^@elsif\s+(.+)$/i
            condition = Regexp.last_match(1).strip

            # If previous condition in chain was true, this branch is false
            # Otherwise, evaluate the condition
            if !condition_stack.empty? && chain_matched_stack.last
              # Previous branch matched, so this one is false
              condition_stack[-1] = false
            else
              # Previous branch didn't match, evaluate this condition
              result = ConditionEvaluator.evaluate(condition, context)
              condition_stack[-1] = result
              chain_matched_stack[-1] = result if result
            end

            # Don't include the @elsif line itself
            next
          end

          # Check for @else
          if line =~ /^@else\s*$/i
            # If any previous condition in chain was true, this branch is false
            # Otherwise, this branch is true
            if !condition_stack.empty? && chain_matched_stack.last
              # Previous branch matched, so else is false
              condition_stack[-1] = false
            else
              # No previous branch matched, so else is true
              condition_stack[-1] = true
              chain_matched_stack[-1] = true
            end

            # Don't include the @else line itself
            next
          end

          # Check for @end - only skip if it's closing an @if/@unless/@elsif/@else block
          if (line =~ /^@end\s*$/) && !condition_stack.empty?
            # This @end closes a conditional block, so skip it
            condition_stack.pop
            chain_matched_stack.pop
            next
          end
          # Otherwise, this @end is for @before/@after, so include it

          # Include the line only if all conditions in stack are true
          output << line if condition_stack.all? { |cond| cond }
        end

        output.join("\n")
      end
    end
  end
end
