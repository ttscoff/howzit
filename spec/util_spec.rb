# frozen_string_literal: true

require 'spec_helper'

describe Howzit::Util do
  subject(:util) { Howzit::Util }

  describe '.read_file' do
    it 'reads file to a string' do
      buildnote = util.read_file('builda.md')
      expect(buildnote).not_to be_empty
      expect(buildnote).to be_a String
    end
  end

  describe '.valid_command?' do
    it 'finds a command' do
      expect(util.command_exist?('ls')).to be_truthy
    end
    it 'validates a command' do
      expect(util.valid_command?('ls -1')).to be_truthy
    end
  end

  describe '.which_highlighter' do
    it 'finds mdless' do
      Howzit.options[:highlighter] = 'mdless'
      expect(util.which_highlighter).to eq 'mdless'
    end
  end

  describe '.which_pager' do
    it 'finds the more utility' do
      Howzit.options[:pager] = 'more'
      expect(util.which_pager).to eq 'more'
      Howzit.options[:pager] = 'auto'
      expect(util.which_pager).to_not eq 'more'
    end
  end

  describe '.show' do
    it 'prints output' do
      buildnote = util.read_file('builda.md')
      expect { util.show(buildnote) }.to output(/Balogna/).to_stdout
    end

    it 'pages output' do
      buildnote = util.read_file('builda.md')
      expect { util.page(buildnote) }.to output(/Balogna/).to_stdout
    end
  end
end
