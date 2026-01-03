# frozen_string_literal: true

require 'spec_helper'

describe Howzit::Topic do
  title = 'Test Title'
  content = 'Test Content'
  subject(:topic) { Howzit::Topic.new(title, content) }

  describe '.new' do
    it 'makes a new topic instance' do
      expect(topic).to be_a described_class
    end

    it 'has the correct title' do
      expect(topic.title).to eq title
    end

    it 'has the correct content' do
      expect(topic.content).to eq content
    end
  end
end

describe Howzit::Topic do
  subject(:topic) do
    bn = Howzit.buildnote
    bn.find_topic('Topic Balogna')[0]
  end

  describe '.title' do
    it 'has the correct title' do
      expect(topic.title).to match(/Topic Balogna/)
    end
  end

  describe '.tasks' do
    it 'has 3 tasks' do
      expect(topic.tasks.count).to eq 3
    end
  end

  describe '.prereqs' do
    it 'has prereq' do
      expect(topic.prereqs.count).to eq 1
    end
  end

  describe '.postreqs' do
    it 'has postreq' do
      expect(topic.postreqs.count).to eq 1
    end
  end

  describe '.grep' do
    it 'returns true for matching pattern in content' do
      expect(topic.grep('prereq.*?ite')).to be_truthy
    end

    it 'returns true for matching pattern in title' do
      expect(topic.grep('bal.*?na')).to be_truthy
    end

    it 'fails on bad pattern' do
      expect(topic.grep('xxx+')).not_to be_truthy
    end
  end

  describe '.run' do
    Howzit.options[:default] = true

    it 'shows prereq and postreq' do
      expect { topic.run }.to output(/prerequisite/).to_stdout
      expect { topic.run }.to output(/postrequisite/).to_stdout
    end

    it 'Copies to clipboard' do
      expect do
        ENV['RUBYOPT'] = '-W1'
        Howzit.options[:log_level] = 0
        Howzit.instance_variable_set(:@console, nil) # Reset console to pick up new log level
        topic.run
      end.to output(/Copied/).to_stderr
    end
  end

  describe '.print_out' do
    before do
      Howzit.options[:header_format] = :block
      Howzit.options[:color] = false
      Howzit.options[:show_all_code] = false
    end

    it 'prints the topic title' do
      expect(topic.print_out({ single: true, header: true }).join("\n").uncolor).to match(/▌Topic Balogna/)
    end

    it 'prints a task title' do
      expect(topic.print_out({ single: true, header: true }).join("\n").uncolor).to match(/▶ Null Output/)
    end

    it 'prints task action with --show-code' do
      Howzit.options[:show_all_code] = true
      expect(topic.print_out({ single: true, header: true }).join("\n").uncolor).to match(/▶ ls -1/)
    end
  end

  describe '.arguments' do
    before do
      Howzit.arguments = []
    end

    it 'extracts named arguments from topic title with defaults' do
      topic = Howzit::Topic.new('Test Topic (var1:default1, var2:default2)', 'Content')
      expect(topic.named_args['var1']).to eq('default1')
      expect(topic.named_args['var2']).to eq('default2')
    end

    it 'does nothing when title has no arguments' do
      topic = Howzit::Topic.new('Test Topic', 'Content')
      expect(topic.named_args).to eq({})
    end

    it 'cleans title after extracting arguments' do
      topic = Howzit::Topic.new('Test Topic (var:val)', 'Content')
      expect(topic.title).to eq('Test Topic')
    end

    it 'uses provided arguments over defaults' do
      Howzit.arguments = ['provided_value']
      topic = Howzit::Topic.new('Test Topic (var:default_value)', 'Content')
      expect(topic.named_args['var']).to eq('provided_value')
    end
  end
end
