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
      ## @param      query    [String] The search term to display in prompt
      ##
      ## @return     [Array] the selected results
      ##
      def choose(matches, height: :auto, query: nil)
        return [] if matches.count.zero?
        return matches if matches.count == 1
        return [] unless $stdout.isatty

        if Util.command_exist?('fzf')
          height = height == :auto ? matches.count + 3 : TTY::Screen.rows

          settings = fzf_options(height, query: query)
          res = `echo #{Shellwords.escape(matches.join("\n"))} | fzf #{settings.join(' ')}`.strip
          return fzf_result(res)
        end

        return gum_choose(matches, query: query, multi: true) if Util.command_exist?('gum')

        tty_menu(matches, query: query)
      end

      def fzf_result(res)
        if res.nil? || res.empty?
          Howzit.console.info 'Cancelled'
          Process.exit 0
        end
        res.split(/\n/)
      end

      def fzf_options(height, query: nil)
        prompt = if query
                   "Select a topic for \\`#{query}\\` > "
                 else
                   'Select a topic > '
                 end
        [
          '-0',
          '-1',
          '-m',
          "--height=#{height}",
          '--header="Tab: add selection, ctrl-a/d: (de)select all, return: display/run"',
          '--bind ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all',
          "--prompt=\"#{prompt}\"",
          %(--preview="howzit --no-pager --header-format block --no-color --default --multiple first {}")
        ]
      end

      ##
      ## Display a numeric menu on the TTY
      ##
      ## @param      matches  The matches from which to select
      ## @param      query    [String] The search term to display
      ##
      def tty_menu(matches, query: nil)
        return matches if matches.count == 1

        @stty_save = `stty -g`.chomp

        trap('INT') do
          system('stty')
          exit
        end

        if query
          begin
            puts "\nSelect a topic for `#{query}`:"
          rescue Errno::EPIPE
            # Pipe closed, ignore
          end
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

          begin
            puts 'Out of range'
          rescue Errno::EPIPE
            # Pipe closed, ignore
          end
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

      ##
      ## Multi-select menu for templates
      ##
      ## @param      matches  [Array] The options list
      ## @param      prompt_text  [String] The prompt to display
      ##
      ## @return     [Array] the selected results (can be empty)
      ##
      def choose_templates(matches, prompt_text: 'Select templates')
        return [] if matches.count.zero?
        return [] unless $stdout.isatty

        if Util.command_exist?('fzf')
          height = matches.count + 3
          settings = fzf_template_options(height, prompt_text: prompt_text)

          # Save terminal state before fzf
          tty_state = `stty -g`.chomp
          res = `echo #{Shellwords.escape(matches.join("\n"))} | fzf #{settings.join(' ')}`.strip
          # Restore terminal state after fzf
          system("stty #{tty_state}")

          return res.empty? ? [] : res.split(/\n/)
        end

        return gum_choose(matches, prompt: prompt_text, multi: true, required: false) if Util.command_exist?('gum')

        text_template_input(matches)
      end

      ##
      ## FZF options for template selection
      ##
      def fzf_template_options(height, prompt_text: 'Select templates')
        [
          '-0',
          '-m',
          "--height=#{height}",
          '--header="Tab: add selection, ctrl-a/d: (de)select all, esc: skip, return: confirm"',
          '--bind ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all',
          "--prompt=\"#{prompt_text} > \""
        ]
      end

      ##
      ## Text-based template input with fuzzy matching
      ##
      ## @param      available  [Array] Available template names
      ##
      ## @return     [Array] Matched template names
      ##
      def text_template_input(available)
        @stty_save = `stty -g`.chomp

        trap('INT') do
          system('stty', @stty_save)
          exit
        end

        begin
          puts "\n{bw}Available templates:{x} #{available.join(', ')}".c
        rescue Errno::EPIPE
          # Pipe closed, ignore
        end
        printf '{bw}Enter templates to include, comma-separated (return to skip):{x} '.c
        input = Readline.readline('', true).strip

        return [] if input.empty?

        fuzzy_match_templates(input, available)
      ensure
        system('stty', @stty_save) if @stty_save
      end

      ##
      ## Fuzzy match user input against available templates
      ##
      ## @param      input      [String] Comma-separated user input
      ## @param      available  [Array] Available template names
      ##
      ## @return     [Array] Matched template names
      ##
      def fuzzy_match_templates(input, available)
        terms = input.split(',').map(&:strip).reject(&:empty?)
        matched = []

        terms.each do |term|
          # Try exact match first (case-insensitive)
          exact = available.find { |t| t.downcase == term.downcase }
          if exact
            matched << exact unless matched.include?(exact)
            next
          end

          # Try fuzzy match using the same regex approach as topic matching
          rx = term.to_rx
          fuzzy = available.select { |t| t =~ rx }

          # Prefer matches that start with the term
          if fuzzy.length > 1
            starts_with = fuzzy.select { |t| t.downcase.start_with?(term.downcase) }
            fuzzy = starts_with unless starts_with.empty?
          end

          fuzzy.each { |t| matched << t unless matched.include?(t) }
        end

        matched
      end

      ##
      ## Prompt for a single line of input
      ##
      ## @param      prompt_text  [String] The prompt to display
      ## @param      default      [String] Default value if empty
      ##
      ## @return     [String] the entered value
      ##
      def get_line(prompt_text, default: nil)
        return default || '' unless $stdout.isatty

        if Util.command_exist?('gum')
          result = gum_input(prompt_text, placeholder: default || '')
          return result.empty? && default ? default : result
        end

        prompt_with_default = default ? "#{prompt_text} [#{default}]: " : "#{prompt_text}: "
        result = Readline.readline(prompt_with_default, true).to_s.strip
        result.empty? && default ? default : result
      end

      ##
      ## Use gum for single or multi-select menu
      ##
      ## @param      matches   [Array] The options list
      ## @param      prompt    [String] The prompt text
      ## @param      multi     [Boolean] Allow multiple selections
      ## @param      required  [Boolean] Require at least one selection
      ## @param      query     [String] The search term for display
      ##
      ## @return     [Array] Selected items
      ##
      def gum_choose(matches, prompt: nil, multi: false, required: true, query: nil)
        prompt_text = prompt || (query ? "Select for '#{query}'" : 'Select')
        args = %w[gum choose]
        args << '--no-limit' if multi
        args << "--header=#{Shellwords.escape(prompt_text)}"
        args << '--cursor.foreground=6'
        args << '--selected.foreground=2'

        tty_state = `stty -g`.chomp
        res = `echo #{Shellwords.escape(matches.join("\n"))} | #{args.join(' ')}`.strip
        system("stty #{tty_state}")

        if res.empty?
          if required
            Howzit.console.info 'Cancelled'
            Process.exit 0
          end
          return []
        end

        res.split(/\n/)
      end

      ##
      ## Use gum for text input
      ##
      ## @param      prompt_text   [String] The prompt to display
      ## @param      placeholder   [String] Placeholder text
      ##
      ## @return     [String] The entered value
      ##
      def gum_input(prompt_text, placeholder: '')
        args = %w[gum input]
        args << "--header=#{Shellwords.escape(prompt_text)}"
        args << "--placeholder=#{Shellwords.escape(placeholder)}" unless placeholder.empty?
        args << '--cursor.foreground=6'

        tty_state = `stty -g`.chomp
        res = `#{args.join(' ')}`.strip
        system("stty #{tty_state}")

        res
      end
    end
  end
end
