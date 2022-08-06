# frozen_string_literal: true

unless ENV['CI'] == 'true'
  # SimpleCov::Formatter::Codecov # For CI
  require 'simplecov'
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
  SimpleCov.start
end

require 'howzit'
require 'cli-test'

RSpec.configure do |c|
  c.expect_with(:rspec) { |e| e.syntax = :expect }

  c.before(:each) do
    allow(FileUtils).to receive(:remove_entry_secure).with(anything)
    save_buildnote
    Howzit.options[:include_upstream] = false
    Howzit.options[:default] = true
    @hz = Howzit.buildnote
  end

  c.after(:each) do
    delete_buildnote
  end
end

def save_buildnote
  note = <<~EONOTE
    # Howzit Test

    ## Topic Balogna

    @before
    This should be a prerequisite.
    @end

    @run(ls -1 &> /dev/null) Null Output
    @include(Topic Tropic)

    @after
    This should be a postrequisite.
    @end

    ## Topic Banana

    This is just another topic.

    - It has a list in it
    - That's pretty fun, right?

    ## Topic Tropic

    Bermuda, Bahama, something something wanna.
    @copy(Balogna) Just some balogna
  EONOTE
  File.open('builda.md', 'w') { |f| f.puts note }
end

def delete_buildnote
  FileUtils.rm('builda.md')
end
