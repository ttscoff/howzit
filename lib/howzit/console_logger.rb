# frozen_string_literal: true

LOG_LEVELS = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3
}.deep_freeze

module Howzit
  # Console logging
  class ConsoleLogger
    attr_accessor :log_level

    def initialize(level = nil)
      @log_level = level.to_i || Howzit.options[:log_level]
    end

    def reset_level
      @log_level = Howzit.options[:log_level]
    end

    def write(msg, level = :info)
      $stderr.puts msg if LOG_LEVELS[level] >= @log_level
    end

    def debug(msg)
      write msg, :debug
    end

    def info(msg)
      write msg, :info
    end

    def warn(msg)
      write msg, :warn
    end

    def error(msg)
      write msg, :error
    end
  end
end
