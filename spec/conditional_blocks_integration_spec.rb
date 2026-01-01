# frozen_string_literal: true

require 'spec_helper'

describe 'Conditional Blocks Integration' do
  before do
    Howzit.options[:include_upstream] = false
    Howzit.options[:default] = true
    Howzit.options[:matching] = 'partial'
    Howzit.options[:multiple_matches] = 'choose'
  end

  after do
    FileUtils.rm_f('builda.md')
  end

  describe 'with conditional blocks in topics' do
    it 'includes content when @if condition is true' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @if "test" == "test"
        This should be included
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil) # Force reload
      topic = Howzit.buildnote.find_topic('Test Topic')[0]
      expect(topic).not_to be_nil
      output = topic.print_out
      expect(output.join("\n")).to include('This should be included')
      expect(output.join("\n")).not_to include('@if')
      expect(output.join("\n")).not_to include('@end')
    end

    it 'excludes content when @if condition is false' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @if "test" == "other"
        This should NOT be included
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil) # Force reload
      topic = Howzit.buildnote.find_topic('Test Topic')[0]
      expect(topic).not_to be_nil
      output = topic.print_out
      expect(output.join("\n")).not_to include('This should NOT be included')
    end

    it 'includes tasks when condition is true' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @if 1 == 1
        @run(echo "test") Test Command
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil) # Force reload
      topic = Howzit.buildnote.find_topic('Test Topic')[0]
      expect(topic).not_to be_nil
      expect(topic.tasks.count).to eq(1)
      expect(topic.tasks[0].action).to include('echo "test"')
    end

    it 'excludes tasks when condition is false' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @if 1 == 2
        @run(echo "hidden") Hidden Command
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil) # Force reload
      topic = Howzit.buildnote.find_topic('Test Topic')[0]
      expect(topic).not_to be_nil
      expect(topic.tasks.count).to eq(0)
    end

    it 'handles nested conditional blocks' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @if "outer" == "outer"
        Outer content
        @if "inner" == "inner"
        Inner content
        @end
        More outer content
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil) # Force reload
      topic = Howzit.buildnote.find_topic('Test Topic')[0]
      expect(topic).not_to be_nil
      output = topic.print_out
      expect(output.join("\n")).to include('Outer content')
      expect(output.join("\n")).to include('Inner content')
      expect(output.join("\n")).to include('More outer content')
    end

    it 'handles metadata in conditions' do
      note = <<~EONOTE
        env: production

        # Test

        ## Test Topic

        @if env == "production"
        Production content
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil) # Force reload
      topic = Howzit.buildnote.find_topic('Test Topic')[0]
      expect(topic).not_to be_nil
      output = topic.print_out
      expect(output.join("\n")).to include('Production content')
    end

    it 'handles @unless blocks correctly' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @unless "test" == "other"
        This should be included
        @end

        @unless "test" == "test"
        This should NOT be included
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil) # Force reload
      topic = Howzit.buildnote.find_topic('Test Topic')[0]
      expect(topic).not_to be_nil
      output = topic.print_out
      expect(output.join("\n")).to include('This should be included')
      expect(output.join("\n")).not_to include('This should NOT be included')
    end
  end
end

