# frozen_string_literal: true

# Main config dir
CONFIG_DIR = '~/.config/howzit'

# Config file name
CONFIG_FILE = 'howzit.yaml'

# Color template name
COLOR_FILE = 'theme.yaml'

# Ignore file name
IGNORE_FILE = 'ignore.yaml'

# Available options for matching method
MATCHING_OPTIONS = %w[partial exact fuzzy beginswith].freeze

# Available options for multiple_matches method
MULTIPLE_OPTIONS = %w[first best all choose].freeze

# Available options for header formatting
HEADER_FORMAT_OPTIONS = %w[border block].freeze

require 'optparse'
require 'shellwords'
require 'pathname'
require 'readline'
require 'tempfile'
require 'yaml'

require_relative 'howzit/util'
require_relative 'howzit/hash'

require_relative 'howzit/version'
require_relative 'howzit/prompt'
require_relative 'howzit/colors'
require_relative 'howzit/stringutils'

require_relative 'howzit/console_logger'
require_relative 'howzit/config'
require_relative 'howzit/task'
require_relative 'howzit/topic'
require_relative 'howzit/buildnote'
require_relative 'howzit/run_report'

require 'tty/screen'
require 'tty/box'
# require 'tty/prompt'

# Main module for howzit
module Howzit
  class << self
    attr_accessor :arguments, :named_arguments, :cli_args, :run_log, :multi_topic_run

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
    def buildnote(file = nil)
      @buildnote ||= BuildNote.new(file: file)
    end

    ##
    ## Convenience method for logging with Howzit.console.warn, etc.
    ##
    def console
      @console ||= Howzit::ConsoleLogger.new(options[:log_level])
    end

    def run_log
      @run_log ||= []
    end

    def multi_topic_run
      @multi_topic_run ||= false
    end

    def has_read_upstream
      @has_read_upstream ||= false
    end

    attr_writer :has_read_upstream, :run_log
  end
end
