require 'howzit/version'
require 'howzit/buildnotes'
require 'howzit/stringutils'
require 'optparse'
require 'shellwords'
require 'pathname'
require 'readline'
require 'tempfile'
require 'yaml'

CONFIG_DIR = '~/.config/howzit'
CONFIG_FILE = 'howzit.yaml'
IGNORE_FILE = 'ignore.yaml'
MATCHING_OPTIONS = %w[partial exact fuzzy beginswith].freeze
