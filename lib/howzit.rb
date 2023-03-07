# frozen_string_literal: true

require_relative 'howzit/version'
require_relative 'howzit/prompt'
require_relative 'howzit/colors'
require_relative 'howzit/stringutils'

require_relative 'howzit/hash'
require_relative 'howzit/console_logger'
require_relative 'howzit/util'
require_relative 'howzit/config'
require_relative 'howzit/task'
require_relative 'howzit/topic'
require_relative 'howzit/buildnote'

require 'optparse'
require 'shellwords'
require 'pathname'
require 'readline'
require 'tempfile'
require 'yaml'

require 'tty/screen'
require 'tty/box'
# require 'tty/prompt'

# Main config dir
CONFIG_DIR = '~/.config/howzit'

# Config file name
CONFIG_FILE = 'howzit.yaml'

# Ignore file name
IGNORE_FILE = 'ignore.yaml'

# Available options for matching method
MATCHING_OPTIONS = %w[partial exact fuzzy beginswith].freeze

# Available options for multiple_matches method
MULTIPLE_OPTIONS = %w[first best all choose].freeze

# Available options for header formatting
HEADER_FORMAT_OPTIONS = %w[border block].freeze

# Main module for howzit
module Howzit
  class << self
    attr_accessor :arguments, :named_arguments, :cli_args
    ##
    ## Holds a Configuration object with methods and a @settings hash
    ##
    ## @return     [Configuration] Configuration object
    ##
    def config
      @config ||= Config.new
    end

    ##
    ## Array for tracking inclusions and avoiding duplicates in output
    ##
    def inclusions
      @inclusions ||= []
    end

    ##
    ## Module storage for Howzit::Config.options
    ##
    def options
      config.options
    end

    ##
    ## Module storage for buildnote
    ##
    def buildnote
      @buildnote ||= BuildNote.new
    end

    ##
    ## Convenience method for logging with Howzit.console.warn, etc.
    ##
    def console
      @console ||= Howzit::ConsoleLogger.new(options[:log_level])
    end

    def has_read_upstream
      @has_read_upstream ||= false
    end

    def has_read_upstream=(has_read)
      @has_read_upstream = has_read
    end
  end
end
