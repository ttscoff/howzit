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
        if Pathname.new(File.expand_path(command)).absolute?
          ::File.exist?(command) || exts.any? { |ext| ::File.exist?("#{command}#{ext}") }
        else
          ENV.fetch('PATH', '').split(::File::PATH_SEPARATOR).any? do |dir|
            file = ::File.join(dir, command)
            ::File.exist?(file) || exts.any? { |ext| ::File.exist?("#{file}#{ext}") }
          end
        end
      end

      # If either mdless or mdcat are installed, use that for highlighting
      # markdown
      def which_highlighter
        if Howzit.options[:highlighter] =~ /auto/i
          highlighters = %w[mdcat mdless]
          highlighters.delete_if(&:nil?).select!(&:available?)
          return nil if highlighters.empty?

          hl = highlighters.first
          args = case hl
                 when 'mdless'
                   '--no-pager'
                 end

          [hl, args].join(' ')
        else
          hl = Howzit.options[:highlighter].split(/ /)[0]
          if hl.available?
            Howzit.options[:highlighter]
          else
            Howzit.console.error Color.template("{Rw}Error:{xbw} Specified highlighter (#{Howzit.options[:highlighter]}) not found, switching to auto")
            Howzit.options[:highlighter] = 'auto'
            which_highlighter
          end
        end
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
          puts text
          return
        end

        read_io, write_io = IO.pipe

        input = $stdin

        pid = Kernel.fork do
          write_io.close
          input.reopen(read_io)
          read_io.close

          # Wait until we have input before we start the pager
          IO.select [input]

          pager = which_pager

          begin
            exec(pager)
          rescue SystemCallError => e
            Howzit.console.error(e)
            exit 1
          end
        end

        read_io.close
        write_io.write(text)
        write_io.close

        _, status = Process.waitpid2(pid)

        status.success?
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

        output = `echo #{Shellwords.escape(string.strip)}#{pipes}`.strip

        if options[:paginate] && Howzit.options[:paginate]
          page(output)
        else
          puts output
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
