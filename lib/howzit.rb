# frozen_string_literal: true

require_relative 'howzit/version'
require_relative 'howzit/prompt'
require_relative 'howzit/colors'
require_relative 'howzit/stringutils'

require_relative 'howzit/util'
require_relative 'howzit/hash'
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
# require 'tty/prompt'

CONFIG_DIR = '~/.config/howzit'
CONFIG_FILE = 'howzit.yaml'
IGNORE_FILE = 'ignore.yaml'
MATCHING_OPTIONS = %w[partial exact fuzzy beginswith].freeze
MULTIPLE_OPTIONS = %w[first best all choose].freeze
HEADER_FORMAT_OPTIONS = %w[border block].freeze

module Howzit
  class << self
    attr_accessor :arguments, :cli_args
    ##
    ## Holds a Configuration object with methods and a @settings hash
    ##
    ## @return     [Configuration] Configuration object
    ##
    def config
      @config ||= Config.new
    end

    def inclusions
      @inclusions ||= []
    end

    def options
      config.options
    end

    def buildnote
      @buildnote ||= BuildNote.new
    end
  end
end
