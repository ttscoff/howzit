# frozen_string_literal: true
IRB.conf[:AUTO_INDENT] = true

require "irb/completion"
require_relative "lib/conductor"

# rubocop:disable Style/MixinUsage
include Howzit # standard:disable all
# rubocop:enable Style/MixinUsage

require "awesome_print"
AwesomePrint.irb!
