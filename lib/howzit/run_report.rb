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
      output_lines = ["\n\n***\n"] + lines
      output_lines.join("\n")
    end

    def format_line(entry, prefix_topic)
      symbol = entry[:success] ? '✅' : '❌'
      parts = ["#{symbol} "]
      parts << "{bw}#{entry[:topic]}{x}: " if prefix_topic && entry[:topic] && !entry[:topic].empty?
      parts << "{by}#{entry[:task]}{x}"
      unless entry[:success]
        reason = entry[:exit_status] ? "exit code #{entry[:exit_status]}" : 'failed'
        parts << " {br}(#{reason}){x}"
      end
      parts.join.c
    end

    # Table formatting methods kept for possible future use
    def format_as_table
      return '' if entries.empty?

      rows = entries.map { |entry| format_row(entry, Howzit.multi_topic_run) }

      # Status column width: " :--: " = 6 chars (4 for :--: plus 1 space each side)
      # Emoji is 2-width in terminal, so we need 2 spaces on each side to center it
      status_width = 6
      task_width = [4, rows.map { |r| r[:task_plain].length }.max].max

      # Build the table with emoji header - center emoji in 6-char column
      header = "|  🚥  | #{'Task'.ljust(task_width)} |"
      separator = "| :--: | #{':' + '-' * (task_width - 1)} |"

      table_lines = [header, separator]
      rows.each do |row|
        table_lines << table_row_colored(row[:status], row[:task], row[:task_plain], status_width, task_width)
      end

      table_lines.join("\n")
    end

    def table_row_colored(status, task, task_plain, status_width, task_width)
      task_padding = task_width - task_plain.length

      "|  #{status}  | #{task}#{' ' * task_padding} |"
    end

    def format_row(entry, prefix_topic)
      # Use plain emoji without color codes - the emoji itself provides visual meaning
      # and complex ANSI codes interfere with mdless table rendering
      symbol = entry[:success] ? '✅' : '❌'

      task_parts = []
      task_parts_plain = []

      if prefix_topic && entry[:topic] && !entry[:topic].empty?
        task_parts << "{bw}#{entry[:topic]}{x}: "
        task_parts_plain << "#{entry[:topic]}: "
      end

      task_parts << "{by}#{entry[:task]}{x}"
      task_parts_plain << entry[:task]

      unless entry[:success]
        reason = entry[:exit_status] ? "exit code #{entry[:exit_status]}" : 'failed'
        task_parts << " {br}(#{reason}){x}"
        task_parts_plain << " (#{reason})"
      end

      {
        status: symbol,
        status_plain: symbol,
        task: task_parts.join.c,
        task_plain: task_parts_plain.join
      }
    end
  end
end
