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
        if Pathname.new(command).absolute?
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
                 when /^(less|more)$/
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

        if Howzit.options[:paginate]
          page(output)
        else
          puts output
        end
      end
    end
  end
end
