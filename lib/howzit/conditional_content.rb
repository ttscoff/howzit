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

            # Don't include the @if/@unless line itself
            next
          end

          # Check for @end - only skip if it's closing an @if/@unless block
          if (line =~ /^@end\s*$/) && !condition_stack.empty?
            # This @end closes an @if/@unless block, so skip it
            condition_stack.pop
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
