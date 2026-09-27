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

    def status_symbol(entry)
      return '⏭️' if entry[:skipped]

      entry[:success] ? '✅' : '❌'
    end

    def status_reason(entry)
      return 'skipped' if entry[:skipped]

      entry[:exit_status] ? "exit code #{entry[:exit_status]}" : 'failed'
    end

    def format_line(entry, prefix_topic)
      symbol = status_symbol(entry)
      parts = ["#{symbol} "]
      if prefix_topic && entry[:topic] && !entry[:topic].empty?
        # Escape braces and dollar signs in topic name to prevent color code interpretation
        topic_escaped = entry[:topic].gsub(/\{/, '\\{').gsub(/\}/, '\\}').gsub(/\$/, '\\$')
        parts << "{bw}#{topic_escaped}{x}: "
      end
      # Escape braces and dollar signs in task name to prevent color code interpretation
      task_escaped = entry[:task].gsub(/\{/, '\\{').gsub(/\}/, '\\}').gsub(/\$/, '\\$')
      if entry[:skipped]
        parts << "{d}#{task_escaped} (skipped){x}"
      else
        parts << "{by}#{task_escaped} {x}"
        parts << " {br}(#{status_reason(entry)}){x}" unless entry[:success]
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
      separator = "| :--: | #{":#{'-' * (task_width - 1)}"} |"

      table_lines = [header, separator]
      rows.each do |row|
        table_lines << table_row_colored(row[:status], row[:task], row[:task_plain], status_width, task_width)
      end

      table_lines.join("\n")
    end

    def table_row_colored(status, task, task_plain, _status_width, task_width)
      task_padding = task_width - task_plain.length

      "|  #{status}  | #{task}#{' ' * task_padding} |"
    end

    def format_row(entry, prefix_topic)
      # Use plain emoji without color codes - the emoji itself provides visual meaning
      # and complex ANSI codes interfere with mdless table rendering
      symbol = status_symbol(entry)

      task_parts = []
      task_parts_plain = []

      if prefix_topic && entry[:topic] && !entry[:topic].empty?
        # Escape braces and dollar signs in topic name to prevent color code interpretation
        topic_escaped = entry[:topic].gsub(/\{/, '\\{').gsub(/\}/, '\\}').gsub(/\$/, '\\$')
        task_parts << "{bw}#{topic_escaped}{x}: "
        task_parts_plain << "#{entry[:topic]}: "
      end

      # Escape braces and dollar signs in task name to prevent color code interpretation
      task_escaped = entry[:task].gsub(/\{/, '\\{').gsub(/\}/, '\\}').gsub(/\$/, '\\$')
      task_parts << "{by}#{task_escaped} {x}"
      task_parts_plain << entry[:task]

      unless entry[:success]
        reason = status_reason(entry)
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
