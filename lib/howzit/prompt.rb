# frozen_string_literal: true

module Howzit
  # Command line prompt utils
  module Prompt
    class << self

      ##
      ## Display and read a Yes/No prompt
      ##
      ## @param      prompt   [String] The prompt string
      ## @param      default  [Boolean] default value if
      ##                      return is pressed or prompt is
      ##                      skipped
      ##
      ## @return     [Boolean] result
      ##
      def yn(prompt, default: true)
        return default unless $stdout.isatty

        return default if Howzit.options[:default]

        tty_state = `stty -g`
        system 'stty raw -echo cbreak isig'
        yn = color_single_options(default ? %w[Y n] : %w[y N])
        $stdout.syswrite "\e[1;37m#{prompt} #{yn}\e[1;37m? \e[0m"
        res = $stdin.sysread 1
        res.chomp!
        puts
        system 'stty cooked'
        system "stty #{tty_state}"
        res.empty? ? default : res =~ /y/i
      end

      ##
      ## Helper function to colorize the Y/N prompt
      ##
      ## @param      choices  [Array] The choices with
      ##                      default capitalized
      ##
      ## @return     [String] colorized string
      ##
      def color_single_options(choices = %w[y n])
        out = []
        choices.each do |choice|
          case choice
          when /[A-Z]/
            out.push(Color.template("{bw}#{choice}{x}"))
          else
            out.push(Color.template("{dw}#{choice}{xg}"))
          end
        end
        Color.template("{xg}[#{out.join('/')}{xg}]{x}")
      end

      ##
      ## Create a numbered list of options. Outputs directly
      ## to console, returns nothing
      ##
      ## @param      matches  [Array] The list items
      ##
      def options_list(matches)
        counter = 1
        puts
        matches.each do |match|
          printf("%<counter>2d ) %<option>s\n", counter: counter, option: match)
          counter += 1
        end
        puts
      end

      ##
      ## Choose from a list of items. If fzf is available,
      ## uses that, otherwise generates its own list of
      ## options and accepts a numeric response
      ##
      ## @param      matches  [Array] The options list
      ## @param      height   [Symbol] height of fzf menu
      ##                      (:auto adjusts height to
      ##                      number of options, anything
      ##                      else gets max height for
      ##                      terminal)
      ##
      ## @return     [Array] the selected results
      ##
      def choose(matches, height: :auto)
        return [] if !$stdout.isatty || matches.count.zero?

        if Util.command_exist?('fzf')
          height = if height == :auto
                     matches.count + 3
                   else
                     TTY::Screen.rows
                   end

          settings = [
            '-0',
            '-1',
            '-m',
            "--height=#{height}",
            '--header="Tab: add selection, ctrl-a/d: (de)select all, return: display/run"',
            '--bind ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all',
            '--prompt="Select a topic > "',
            %(--preview="howzit --no-pager --header-format block --no-color --default --multiple first {}")
          ]
          res = `echo #{Shellwords.escape(matches.join("\n"))} | fzf #{settings.join(' ')}`.strip
          if res.nil? || res.empty?
            Howzit.console.info 'Cancelled'
            Process.exit 0
          end
          return res.split(/\n/)
        end

        return matches if matches.count == 1

        res = matches[0..9]
        stty_save = `stty -g`.chomp

        trap('INT') do
          system('stty', stty_save)
          exit
        end

        options_list(matches)

        begin
          printf("Type 'q' to cancel, enter for first item", res.length)
          while (line = Readline.readline(': ', true))
            if line =~ /^[a-z]/i
              system('stty', stty_save) # Restore
              exit
            end
            line = line == '' ? 1 : line.to_i

            return [matches[line - 1]] if line.positive? && line <= matches.length

            puts 'Out of range'
            options_list(matches)
          end
        ensure
          system('stty', stty_save)
          exit
        end
      end
    end
  end
end
