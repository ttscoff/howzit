# frozen_string_literal: true

require 'spec_helper'

describe Howzit::BuildNote do
  subject(:how) { Howzit.buildnote('builda.md') }

  describe ".note_file" do
    it "locates a build note file" do
      expect(how.note_file).not_to be_empty
      expect(how.note_file).to match /builda.md$/
    end
  end

  describe ".grep" do
    it "finds topic containing 'bermuda'" do
      expect(how.grep('bermuda').map { |topic| topic.title }).to include('Topic Tropic')
    end
    it "does not return non-matching topic" do
      expect(how.grep('bermuda').map { |topic| topic.title }).not_to include('Topic Balogna')
    end
  end

  describe ".find_topic" do
    it "finds the Topic Tropic topic" do
      matches = how.find_topic('tropic')
      expect(matches.count).to eq 1
      expect(matches[0].title).to eq 'Topic Tropic'
    end

    it "fuzzy matches" do
      Howzit.options[:matching] = 'fuzzy'
      matches = how.find_topic('trpc')
      expect(matches.count).to eq 1
      expect(matches[0].title).to eq 'Topic Tropic'
    end

    it "succeeds with partial match" do
      Howzit.options[:matching] = 'partial'
      matches = how.find_topic('trop')
      expect(matches.count).to eq 1
      expect(matches[0].title).to eq 'Topic Tropic'
    end

    it "succeeds with beginswith match" do
      Howzit.options[:matching] = 'beginswith'
      matches = how.find_topic('topic')
      expect(matches.count).to eq 3
      expect(matches[0].title).to eq 'Topic Balogna'
    end

    it "succeeds with exact match" do
      Howzit.options[:matching] = 'exact'
      matches = how.find_topic('topic tropic')
      expect(matches.count).to eq 1
      expect(matches[0].title).to eq 'Topic Tropic'
    end

    it "fails with incomplete exact match" do
      Howzit.options[:matching] = 'exact'
      matches = how.find_topic('topic trop')
      expect(matches.count).to eq 0
    end

    it "matches topics containing colon even without space" do
      matches = how.find_topic('git:clean')
      expect(matches.count).to eq 1
      expect(matches[0].title).to eq 'Git: Clean Repo'
    end

    it "Handles multiple matches with best match" do
      Howzit.options[:matching] = 'fuzzy'
      Howzit.options[:multiple_matches] = :best
      matches = how.find_topic('banana')
      expect(matches.first.title).to match(/banana/i)
    end
  end

  describe ".find_topic_exact" do
    it "finds exact whole-word match" do
      matches = how.find_topic_exact('Topic Tropic')
      expect(matches.count).to eq 1
      expect(matches[0].title).to eq 'Topic Tropic'
    end

    it "finds exact match case-insensitively" do
      matches = how.find_topic_exact('topic tropic')
      expect(matches.count).to eq 1
      expect(matches[0].title).to eq 'Topic Tropic'
    end

    it "does not match partial phrases" do
      matches = how.find_topic_exact('topic trop')
      expect(matches.count).to eq 0
    end

    it "does not match single word when phrase has multiple words" do
      matches = how.find_topic_exact('topic')
      expect(matches.count).to eq 0
    end

    it "matches single-word topics" do
      matches = how.find_topic_exact('Happy Bgagngagnga')
      expect(matches.count).to eq 1
      expect(matches[0].title).to eq 'Happy Bgagngagnga'
    end

    it "matches topics with colons" do
      matches = how.find_topic_exact('Git: Clean Repo')
      expect(matches.count).to eq 1
      expect(matches[0].title).to eq 'Git: Clean Repo'
    end
  end

  describe ".topics" do
    it "contains 7 topics" do
      expect(how.list_topics.count).to eq 7
    end
    it "outputs a newline-separated string for completion" do
      expect(how.list_completions.scan(/\n/).count).to eq 6
    end
  end

  describe "#topic_search_terms_from_cli" do
    after { Howzit.cli_args = [] }

    it "respects separators found inside topics" do
      Howzit.cli_args = ['git:clean:blog:update post']
      expect(how.send(:topic_search_terms_from_cli)).to eq(['git:clean', 'blog:update post'])
    end

    it "keeps comma inside matching topics" do
      Howzit.cli_args = ['release, deploy,topic balogna']
      expect(how.send(:topic_search_terms_from_cli)).to eq(['release, deploy', 'topic balogna'])
    end
  end
end
