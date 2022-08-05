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

    ##
    ## Init the console logging object
    ##
    ## @param      level  [Integer] log level
    ##
    def initialize(level = nil)
      @log_level = level.to_i || Howzit.options[:log_level]
    end

    ##
    ## Get the log level from options
    ##
    ## @return     [Integer] log level
    ##
    def reset_level
      @log_level = Howzit.options[:log_level]
    end

    ##
    ## Write a message to the console based on the urgency
    ## level and user's log level setting
    ##
    ## @param      msg    [String] The message
    ## @param      level  [Symbol] The level
    ##
    def write(msg, level = :info)
      $stderr.puts msg if LOG_LEVELS[level] >= @log_level
    end

    ##
    ## Write a message at debug level
    ##
    ## @param      msg   The message
    ##
    def debug(msg)
      write msg, :debug
    end

    ##
    ## Write a message at info level
    ##
    ## @param      msg   The message
    ##
    def info(msg)
      write msg, :info
    end

    ##
    ## Write a message at warn level
    ##
    ## @param      msg   The message
    ##
    def warn(msg)
      write msg, :warn
    end

    ##
    ## Write a message at error level
    ##
    ## @param      msg   The message
    ##
    def error(msg)
      write msg, :error
    end
  end
end
