# frozen_string_literal: true

module Howzit
  # Util class
  module Util
    class << self
      ##
      ## Read a file with UTF-8 encoding and
      ## leading/trailing whitespace removed
      ##
      ## @param      path  [String] The path to read
      ##
      ## @return     [String] UTF-8 encoded string
      ##
      def read_file(path)
        IO.read(path).force_encoding('utf-8').strip
      end

      ##
      ## Test if an external command exists and is
      ## executable. Removes additional arguments and passes
      ## just the executable to #command_exist?
      ##
      ## @param      command  [String] The command
      ##
      ## @return     [Boolean] command is valid
      ##
      def valid_command?(command)
        cmd = command.split(' ')[0]
        command_exist?(cmd)
      end

      ##
      ## Test if external command exists
      ##
      ## @param      command  [String] The command
      ##
      ## @return     [Boolean] command exists
      ##
      def command_exist?(command)
        exts = ENV.fetch('PATHEXT', '').split(::File::PATH_SEPARATOR)
        command = File.expand_path(command) if command =~ /^~/
        if Pathname.new(command).absolute?
          ::File.exist?(command) || exts.any? { |ext| ::File.exist?("#{command}#{ext}") }
        else
          ENV.fetch('PATH', '').split(::File::PATH_SEPARATOR).any? do |dir|
            file = ::File.join(dir, command)
            ::File.exist?(file) || exts.any? { |ext| ::File.exist?("#{file}#{ext}") }
          end
        end
      end

      # Prefer apex, then mdcat, then mdless. mdless ships with the gem,
      # so highlighting still works when apex is not installed.
      def which_highlighter
        command = if Howzit.options[:highlighter] =~ /auto/i
                    auto_highlighter
                  else
                    configured_highlighter
                  end
        apex_command(command)
      end

      # Apex defaults to HTML. Howzit always wants terminal escapes, and it
      # pages the result itself, so add those flags unless the command
      # already sets a format or a pagination option. This covers both
      # auto and an explicit `:highlighter: apex`.
      def apex_command(command)
        return command if command.nil? || command.empty?
        return command unless command.split.first == 'apex'

        args = command.split[1..]
        has_format = args.any? { |arg| ['-t', '--to'].include?(arg) || arg.start_with?('--to=') }
        args.push('-t', 'terminal256') unless has_format
        has_pager = args.any? { |arg| ['--no-paginate', '--paginate', '-p'].include?(arg) }
        args << '--no-paginate' unless has_pager
        ['apex', *args].join(' ')
      end

      def auto_highlighter
        highlighters = %w[apex mdcat mdless]
        highlighters.delete_if(&:nil?).select!(&:available?)
        return nil if highlighters.empty?

        hl = highlighters.first
        args = '--no-pager' if hl == 'mdless'
        [hl, args].compact.join(' ')
      end

      def configured_highlighter
        hl = Howzit.options[:highlighter].split(/ /)[0]
        return Howzit.options[:highlighter] if hl.available?

        Howzit.console.error Color.template("{Rw}Error:{xbw} Specified highlighter (#{Howzit.options[:highlighter]}) not found, switching to auto")
        Howzit.options[:highlighter] = 'auto'
        auto_highlighter
      end

      # When pagination is enabled, find the best (in my opinion) option,
      # favoring environment settings
      def which_pager
        if Howzit.options[:pager] =~ /auto/i
          pagers = [ENV['PAGER'], ENV['GIT_PAGER'],
                    'bat', 'less', 'more', 'pager']
          pagers.delete_if(&:nil?).select!(&:available?)
          return nil if pagers.empty?

          pg = pagers.first
          args = case pg
                 when 'delta'
                   '--pager="less -FXr"'
                 when 'less'
                   '-FXr'
                 when 'bat'
                   if Howzit.options[:highlight]
                     '--language Markdown --style plain --pager="less -FXr"'
                   else
                     '--style plain --pager="less -FXr"'
                   end
                 else
                   ''
                 end

          [pg, args].join(' ')
        else
          pg = Howzit.options[:pager].split(/ /)[0]
          if pg.available?
            Howzit.options[:pager]
          else
            Howzit.console.error Color.template("{Rw}Error:{xbw} Specified pager (#{Howzit.options[:pager]}) not found, switching to auto")
            Howzit.options[:pager] = 'auto'
            which_pager
          end
        end
      end

      # Paginate the output
      def page(text)
        unless $stdout.isatty
          begin
            puts text
          rescue Errno::EPIPE
            # Pipe closed, ignore
          end
          return true
        end

        pager = which_pager
        if pager.nil?
          begin
            puts text
          rescue Errno::EPIPE
            # Pipe closed, ignore
          end
          return true
        end

        # Write the full buffer to the pager stdin before closing it. The old
        # fork + IO.select approach started less as soon as the first bytes
        # arrived, which could leave the initial viewport scrolled past line 1.
        IO.popen(pager, 'w') do |io|
          io.write(text)
        rescue Errno::EPIPE
          # User quit pager before we finished writing, ignore
        end

        Process.last_status.success?
      end

      # Strip safely when external encoding rejects multibyte content (e.g. US-ASCII default).
      def safe_strip(str)
        s = str.to_s
        s.strip
      rescue Encoding::CompatibilityError
        s.encode('UTF-8', invalid: :replace, undef: :replace).strip
      end

      # print output to terminal
      def show(string, opts = {})
        options = {
          color: true,
          highlight: false,
          paginate: true,
          wrap: 0
        }

        options.merge!(opts)

        string = string.uncolor unless options[:color]

        pipes = ''
        if options[:highlight]
          hl = which_highlighter
          pipes = "|#{hl}" if hl
        end

        string = safe_strip(string)

        raw_output = `echo #{Shellwords.escape(string)}#{pipes}`
        output = safe_strip(raw_output)

        if options[:paginate] && Howzit.options[:paginate]
          page(output)
        else
          begin
            puts output
          rescue Errno::EPIPE
            # Pipe closed, ignore
          end
        end
      end

      ##
      ## Platform-agnostic copy-to-clipboard
      ##
      ## @param      string  [String] The string to copy
      ##
      def os_copy(string)
        os = RbConfig::CONFIG['target_os']
        out = "{bg}Copying {bw}#{string}".c
        case os
        when /darwin.*/i
          Howzit.console.debug("#{out} (macOS){x}".c)
          `echo #{Shellwords.escape(string)}'\\c'|pbcopy`
        when /mingw|mswin/i
          Howzit.console.debug("#{out} (Windows){x}".c)
          `echo #{Shellwords.escape(string)} | clip`
        else
          if 'xsel'.available?
            Howzit.console.debug("#{out} (Linux, xsel){x}".c)
            `echo #{Shellwords.escape(string)}'\\c'|xsel -i`
          elsif 'xclip'.available?
            Howzit.console.debug("#{out} (Linux, xclip){x}".c)
            `echo #{Shellwords.escape(string)}'\\c'|xclip -i`
          else
            Howzit.console.debug(out)
            Howzit.console.warn('Unable to determine executable for clipboard.')
          end
        end
      end

      ##
      ## Platform-agnostic paste-from-clipboard
      ##
      def os_paste
        os = RbConfig::CONFIG['target_os']
        out = '{bg}Pasting from clipboard'.c
        case os
        when /darwin.*/i
          Howzit.console.debug("#{out} (macOS){x}".c)
          `pbpaste`
        when /mingw|mswin/i
          Howzit.console.debug("#{out} (Windows){x}".c)
          `cat /dev/clipboard`
        else
          if 'xsel'.available?
            Howzit.console.debug("#{out} (Linux, xsel){x}".c)
            `xsel --clipboard --output`
          elsif 'xclip'.available?
            Howzit.console.debug("#{out} (Linux, xclip){x}".c)
            `xclip -selection clipboard -o`
          else
            Howzit.console.debug(out)
            Howzit.console.warn('Unable to determine executable for clipboard.')
          end
        end
      end

      ##
      ## Platform-agnostic open command
      ##
      ## @param      command  [String] The command
      ##
      def os_open(command)
        os = RbConfig::CONFIG['target_os']
        out = "{bg}Opening {bw}#{command}".c
        case os
        when /darwin.*/i
          Howzit.console.debug "#{out} (macOS){x}".c if Howzit.options[:log_level] < 2
          `open #{Shellwords.escape(command)}`
        when /mingw|mswin/i
          Howzit.console.debug "#{out} (Windows){x}".c if Howzit.options[:log_level] < 2
          `start #{Shellwords.escape(command)}`
        else
          if 'xdg-open'.available?
            Howzit.console.debug "#{out} (Linux){x}".c if Howzit.options[:log_level] < 2
            `xdg-open #{Shellwords.escape(command)}`
          else
            Howzit.console.debug out if Howzit.options[:log_level] < 2
            Howzit.console.debug 'Unable to determine executable for `open`.'
          end
        end
      end
    end
  end
end
