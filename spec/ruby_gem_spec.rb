require 'spec_helper'

describe Howzit::BuildNotes do
  subject(:ruby_gem) { Howzit::BuildNotes.new([]) }

  describe ".new" do
    it "makes a new instance" do
      expect(ruby_gem).to be_a Howzit::BuildNotes
    end
  end
end

describe Howzit::BuildNotes do
  Dir.chdir('spec')
  how = Howzit::BuildNotes.new(['--no-upstream', '--default'])
  how.create_note
  subject { how }

  describe ".note_file" do
    it "locates a build note file" do
      expect(subject.note_file).not_to be_empty
    end
  end

  describe ".grep_topics" do
    it "finds editable" do
      expect(subject.grep_topics('editable')).to include('File Structure')
      expect(subject.grep_topics('editable')).not_to include('Build')
    end
  end

  describe ".list_topic_titles" do
    it "finds 4 topics" do
      expect(subject.topics.keys.count).to eq 4
    end
    it "outputs a newline-separated string" do
      expect(subject.list_topic_titles.scan(/\n/).count).to eq 3
    end
  end
end
