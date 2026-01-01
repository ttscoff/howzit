# frozen_string_literal: true

module Howzit
  # Script Communication module
  # Handles communication from scripts to Howzit via a communication file
  module ScriptComm
    class << self
      ##
      ## Create a communication file for scripts to write to
      ##
      ## @return     [String] Path to the communication file
      ##
      def create_comm_file
        file = Tempfile.new('howzit_comm')
        file.close
        file.path
      end

      ##
      ## Set up the communication file and environment variable
      ##
      ## @return     [String] Path to the communication file
      ##
      def setup
        comm_file = create_comm_file
        ENV['HOWZIT_COMM_FILE'] = comm_file
        comm_file
      end

      ##
      ## Read and process the communication file after script execution
      ##
      ## @param      comm_file  [String] Path to the communication file
      ##
      ## @return     [Hash] Hash with :logs and :vars keys
      ##
      def process(comm_file)
        return { logs: [], vars: {} } unless File.exist?(comm_file)

        logs = []
        vars = {}

        begin
          content = File.read(comm_file)
          content.each_line do |line|
            line = line.strip
            next if line.empty?

            case line
            when /^LOG:(info|warn|error|debug):(.+)$/i
              level = Regexp.last_match(1).downcase.to_sym
              message = Regexp.last_match(2)
              logs << { level: level, message: message }
            when /^VAR:([A-Z0-9_]+)=(.*)$/i
              key = Regexp.last_match(1)
              value = Regexp.last_match(2)
              vars[key] = value
            end
          end
        rescue StandardError => e
          Howzit.console&.warn("Error reading communication file: #{e.message}")
        ensure
          # Clean up the file
          File.unlink(comm_file) if File.exist?(comm_file)
        end

        { logs: logs, vars: vars }
      end

      ##
      ## Process communication and apply logs/variables
      ##
      ## @param      comm_file  [String] Path to the communication file
      ##
      def apply(comm_file)
        result = process(comm_file)
        return if result[:logs].empty? && result[:vars].empty?

        # Apply log messages
        result[:logs].each do |log_entry|
          level = log_entry[:level]
          message = log_entry[:message]
          next unless Howzit.console

          case level
          when :info
            Howzit.console.info(message)
          when :warn
            Howzit.console.warn(message)
          when :error
            Howzit.console.error(message)
          when :debug
            Howzit.console.debug(message)
          end
        end

        # Apply variables to named_arguments
        return if result[:vars].empty?

        Howzit.named_arguments ||= {}
        Howzit.named_arguments.merge!(result[:vars])
      end
    end
  end
end
