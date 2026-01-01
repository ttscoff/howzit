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
    # Reset buildnote cache to ensure fresh instance with updated file
    Howzit.instance_variable_set(:@buildnote, nil)
    Howzit.options[:include_upstream] = false
    Howzit.options[:default] = true
    Howzit.options[:matching] = 'partial'
    Howzit.options[:multiple_matches] = 'choose'
    @hz = Howzit.buildnote
  end

  c.after(:each) do
    delete_buildnote
  end
end

def save_buildnote
  note = <<~EONOTE
    defined: this is defined

    # Howzit Test

    ## Topic Balogna

    @before
    This should be a prerequisite.
    @end

    @run(ls -1 &> /dev/null) Null Output
    @include(Topic Tropic)

    ```run
    #!/usr/bin/env ruby
    title = "[%undefined]".empty? ? "[%defined]" : "[%undefined]"
    ```

    @after
    This should be a postrequisite.
    @end

    ## Topic Banana

    This is just another topic.

    - It has a list in it
    - That's pretty fun, right?
    - Defined: '[%defined]'
    - Undefined: '[%undefined]'

    ## Topic Tropic

    Bermuda, Bahama, something something wanna.
    @copy(Balogna) Just some balogna

    ## Happy Bgagngagnga

    This one is just to throw things off

    ## Git: Clean Repo

    Keep Git projects tidy.

    ## Blog: Update Post

    Publish the latest article updates.

    ## Release, Deploy

    Prep and deploy the latest release.
  EONOTE
  File.open('builda.md', 'w') { |f| f.puts note }
  # puts "Saved to builda.md: #{File.exist?('builda.md')}"
end

def delete_buildnote
  FileUtils.rm_f('builda.md')
end
