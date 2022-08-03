module Howzit
  module Util
    class << self
      def valid_command?(command)
        cmd = command.split(' ')[0]
        command_exist?(cmd)
      end
      
      def command_exist?(command)
        exts = ENV.fetch('PATHEXT', '').split(::File::PATH_SEPARATOR)
        if Pathname.new(command).absolute?
          ::File.exist?(command) ||
            exts.any? { |ext| ::File.exist?("#{command}#{ext}") }
        else
          ENV.fetch('PATH', '').split(::File::PATH_SEPARATOR).any? do |dir|
            file = ::File.join(dir, command)
            ::File.exist?(file) ||
              exts.any? { |ext| ::File.exist?("#{file}#{ext}") }
          end
        end
      end
    end
  end
end
