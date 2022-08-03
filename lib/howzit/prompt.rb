# frozen_string_literal: true

module Howzit
  # Command line prompt utils
  module Prompt
    class << self
    	def yn(prompt, default = true)
        return default if !$stdout.isatty

      	system 'stty cbreak'
      	yn = color_single_options(default ? %w[Y n] : %w[y N])
      	$stdout.syswrite "\e[1;37m#{prompt} #{yn}\e[1;37m? \e[0m"
      	res = $stdin.sysread 1
      	res.chomp!
      	puts
      	system 'stty cooked'
      	res =~ /y/i
      end

      def color_single_options(choices = %w[y n])
        out = []
        choices.each do |choice|
          case choice
          when /[A-Z]/
            out.push(Color.template("{bg}#{choice}{xg}"))
          else
            out.push(Color.template("{w}#{choice}"))
          end
        end
        Color.template("{g}[#{out.join('/')}{g}]{x}")
      end

      def options_list(matches)
        counter = 1
        puts
        matches.each do |match|
          printf("%<counter>2d ) %<option>s\n", counter: counter, option: match)
          counter += 1
        end
        puts
      end

      def choose(matches)
        if Util.command_exist?('fzf')
          settings = [
            '-0',
            '-1',
            '-m',
            "--height=#{matches.count + 2}",
            '--header="Use tab to mark multiple selections, enter to display/run"',
            '--prompt="Select a section > "'
          ]
          res = `echo #{Shellwords.escape(matches.join("\n"))} | fzf #{settings.join(' ')}`.strip
          if res.nil? || res.empty?
            warn 'Cancelled'
            Process.exit 0
          end
          return res.split(/\n/)
        end

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

            return matches[line - 1] if line.positive? && line <= matches.length

            puts 'Out of range'
            options_list(matches)
          end
        rescue Interrupt
          system('stty', stty_save)
          exit
        end
      end
    end
  end
end
