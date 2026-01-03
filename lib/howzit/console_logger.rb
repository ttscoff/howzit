# frozen_string_literal: true

# Available log levels
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
    ## Get emoji for log level
    ##
    ## @param      level  [Symbol] The level
    ##
    ## @return     [String] Emoji for the level
    ##
    def emoji_for_level(level)
      case level
      when :debug
        '🔍'
      when :info
        'ℹ️'
      when :warn
        '⚠️'
      when :error
        '❌'
      else
        ''
      end
    end

    ##
    ## Get color prefix for log level
    ##
    ## @param      level  [Symbol] The level
    ##
    ## @return     [String] Color template string
    ##
    def color_for_level(level)
      case level
      when :debug
        '{d}'
      when :info
        '{c}'
      when :warn
        '{y}'
      when :error
        '{r}'
      else
        ''
      end
    end

    ##
    ## Write a message to the console based on the urgency
    ## level and user's log level setting
    ##
    ## @param      msg    [String] The message
    ## @param      level  [Symbol] The level
    ##
    def write(msg, level = :info)
      return unless LOG_LEVELS[level] >= @log_level

      emoji = emoji_for_level(level)
      color = color_for_level(level)
      formatted_msg = if emoji && color
                        "#{emoji} #{color}#{msg}{x}".c
                       else
                         msg
                       end

      begin
        $stderr.puts formatted_msg
      rescue Errno::EPIPE
        # Pipe closed, ignore
      end
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
      return unless LOG_LEVELS[:warn] >= @log_level

      emoji = emoji_for_level(:warn)
      color = color_for_level(:warn)
      formatted_msg = if emoji && color
                         "#{emoji} #{color}#{msg}{x}".c
                       else
                         msg
                       end

      begin
        $stderr.puts formatted_msg
      rescue Errno::EPIPE
        # Pipe closed, ignore
      end
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
