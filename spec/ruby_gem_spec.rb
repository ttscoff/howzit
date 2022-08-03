require 'spec_helper'

describe Howzit::BuildNote do
  subject(:ruby_gem) { Howzit::BuildNote.new(args: []) }

  describe ".new" do
    it "makes a new instance" do
      expect(ruby_gem).to be_a Howzit::BuildNote
    end
  end
end

describe Howzit::Task do
  subject(:task) { Howzit::Task.new(:run, 'List Directory', 'ls') }

  describe ".new" do
    it "makes a new task instance" do
      expect(task).to be_a Howzit::Task
    end
  end
end

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

describe Howzit::BuildNote do
  Dir.chdir('spec')
  Howzit.options[:include_upstream] = false
  Howzit.options[:default] = true
  hz = Howzit.buildnote

  hz.create_note
  subject(:how) { hz }

  describe ".note_file" do
    it "locates a build note file" do
      expect(how.note_file).not_to be_empty
    end
  end

  describe ".grep" do
    it "finds topic containing 'editable'" do
      expect(how.grep('editable').map { |topic| topic.title }).to include('File Structure')
    end
    it "does not return non-matching topic" do
      expect(how.grep('editable').map { |topic| topic.title }).not_to include('Build')
    end
  end

  describe ".topics" do
    it "contains 4 topics" do
      expect(how.list_topics.count).to eq 4
    end
    it "outputs a newline-separated string for completion" do
      expect(how.list_completions.scan(/\n/).count).to eq 3
    end
  end
end
