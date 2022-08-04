# frozen_string_literal: true

require 'spec_helper'

describe Howzit::Topic do
  title = 'Test Title'
  content = 'Test Content'
  subject(:topic) { Howzit::Topic.new(title, content) }

  describe ".new" do
    it "makes a new topic instance" do
      expect(topic).to be_a Howzit::Topic
    end
    it "has the correct title" do
      expect(topic.title).to eq title
    end
    it "has the correct content" do
      expect(topic.content).to eq content
    end
  end
end

describe Howzit::Topic do
  subject(:topic) { @hz.find_topic('Topic Balogna')[0] }

  describe ".title" do
    it "has the correct title" do
      expect(topic.title).to match /Topic Balogna/
    end
  end

  describe ".tasks" do
    it "has 2 tasks" do
      expect(topic.tasks.count).to eq 2
    end
  end

  describe ".prereqs" do
    it "has prereq" do
      expect(topic.prereqs.count).to eq 1
    end
    it "has postreq" do
      expect(topic.postreqs.count).to eq 1
    end
  end

  describe ".run" do
    Howzit.options[:default] = true
    it "shows prereq and postreq" do
      expect { topic.run }.to output(/prerequisite/).to_stdout
      expect { topic.run }.to output(/postrequisite/).to_stdout
    end
    it "Copies to clipboard" do
      expect {
        ENV['RUBYOPT'] = '-W1'
        Howzit.options[:log_level] = 0
        topic.run
      }.to output(/Copied/).to_stderr
    end
  end
end
