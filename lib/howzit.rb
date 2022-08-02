require 'howzit/version'
require 'howzit/prompt'
require 'howzit/colors'
require 'howzit/buildnotes'
require 'howzit/stringutils'
require 'optparse'
require 'shellwords'
require 'pathname'
require 'readline'
require 'tempfile'
require 'yaml'

require 'tty/screen'

CONFIG_DIR = '~/.config/howzit'
CONFIG_FILE = 'howzit.yaml'
IGNORE_FILE = 'ignore.yaml'
MATCHING_OPTIONS = %w[partial exact fuzzy beginswith].freeze
MULTIPLE_OPTIONS = %w[first best all choose].freeze
