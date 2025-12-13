# frozen_string_literal: true

module Howzit
  # Formatter for task run summaries
  module RunReport
    module_function

    def reset
      Howzit.run_log = []
    end

    def log(entry)
      Howzit.run_log = [] if Howzit.run_log.nil?
      Howzit.run_log << entry
    end

    def entries
      Howzit.run_log || []
    end

    def format
      return '' if entries.empty?

      lines = entries.map { |entry| format_line(entry, Howzit.multi_topic_run) }
      lines.map! { |line| line.rstrip }
      widths = lines.map { |line| line.uncolor.length }
      width = widths.max
      top = '=' * width
      bottom = '-' * width
      output_lines = [top] + lines + [bottom]
      result = output_lines.join("\n")
      result = result.gsub(/\n[ \t]+\n/, "\n")
      result.gsub(/\n{2,}/, "\n")
    end

    def format_line(entry, prefix_topic)
      bullet_start = '{mb}- [{x}'
      bullet_end = '{mb}] {x}'
      symbol = entry[:success] ? '{bg}✓{x}' : '{br}X{x}'
      parts = []
      parts << "#{bullet_start}#{symbol}#{bullet_end}"
      parts << "{bl}#{entry[:topic]}{x}: " if prefix_topic && entry[:topic] && !entry[:topic].empty?
      parts << "{by}#{entry[:task]}{x}"
      unless entry[:success]
        reason = entry[:exit_status] ? "exit code #{entry[:exit_status]}" : 'failed'
        parts << " {br}(Failed: #{reason}){x}"
      end
      parts.join.c
    end
  end
end
