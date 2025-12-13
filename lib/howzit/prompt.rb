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

        return true if Howzit.options[:yes]

        return false if Howzit.options[:no]

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
        return [] if matches.count.zero?
        return matches if matches.count == 1
        return [] unless $stdout.isatty

        if Util.command_exist?('fzf')
          height = height == :auto ? matches.count + 3 : TTY::Screen.rows

          settings = fzf_options(height)
          res = `echo #{Shellwords.escape(matches.join("\n"))} | fzf #{settings.join(' ')}`.strip
          return fzf_result(res)
        end

        tty_menu(matches)
      end

      def fzf_result(res)
        if res.nil? || res.empty?
          Howzit.console.info 'Cancelled'
          Process.exit 0
        end
        res.split(/\n/)
      end

      def fzf_options(height)
        [
          '-0',
          '-1',
          '-m',
          "--height=#{height}",
          '--header="Tab: add selection, ctrl-a/d: (de)select all, return: display/run"',
          '--bind ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all',
          '--prompt="Select a topic > "',
          %(--preview="howzit --no-pager --header-format block --no-color --default --multiple first {}")
        ]
      end

      ##
      ## Display a numeric menu on the TTY
      ##
      ## @param      matches  The matches from which to select
      ##
      def tty_menu(matches)
        return matches if matches.count == 1

        @stty_save = `stty -g`.chomp

        trap('INT') do
          system('stty')
          exit
        end

        options_list(matches)
        read_selection(matches)
      end

      ##
      ## Read a single number response from the command line
      ##
      ## @param      matches  The matches
      ##
      def read_selection(matches)
        printf "Type 'q' to cancel, enter for first item"
        while (line = Readline.readline(': ', true))
          line = read_num(line)

          return [matches[line - 1]] if line.positive? && line <= matches.length

          puts 'Out of range'
          read_selection(matches)
        end
      ensure
        system('stty', @stty_save)
      end

      ##
      ## Request editor
      ##
      def read_editor(default = nil)
        @stty_save = `stty -g`.chomp

        default ||= 'vim'
        prompt = "Define a default editor command (default #{default}): "
        res = Readline.readline(prompt, true).squeeze(' ').strip
        res = default if res.empty?

        Util.valid_command?(res) ? res : default
      ensure
        system('stty', @stty_save)
      end

      ##
      ## Convert a response to an Integer
      ##
      ## @param      line  The response to convert
      ##
      def read_num(line)
        if line =~ /^[a-z]/i
          system('stty', @stty_save) # Restore
          exit
        end
        line == '' ? 1 : line.to_i
      end
    end
  end
end
