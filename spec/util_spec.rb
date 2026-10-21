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
    after { Howzit.options[:highlighter] = 'auto' }

    it 'finds mdless' do
      Howzit.options[:highlighter] = 'mdless'
      expect(util.which_highlighter).to eq 'mdless'
    end

    it 'prefers apex with terminal256 output and pagination disabled' do
      Howzit.options[:highlighter] = 'auto'
      allow(util).to receive(:command_exist?).and_return(false)
      allow(util).to receive(:command_exist?).with('apex').and_return(true)

      expect(util.which_highlighter).to eq 'apex -t terminal256 --no-paginate'
    end

    it 'uses mdcat when apex is not installed' do
      Howzit.options[:highlighter] = 'auto'
      allow(util).to receive(:command_exist?).and_return(false)
      allow(util).to receive(:command_exist?).with('mdcat').and_return(true)

      expect(util.which_highlighter).to eq 'mdcat'
    end

    it 'uses mdless without its pager when apex and mdcat are not installed' do
      Howzit.options[:highlighter] = 'auto'
      allow(util).to receive(:command_exist?).and_return(false)
      allow(util).to receive(:command_exist?).with('mdless').and_return(true)

      expect(util.which_highlighter).to eq 'mdless --no-pager'
    end

    it 'adds terminal256 output when the highlighter is set to apex' do
      Howzit.options[:highlighter] = 'apex'
      allow(util).to receive(:command_exist?).with('apex').and_return(true)

      expect(util.which_highlighter).to eq 'apex -t terminal256 --no-paginate'
    end

    it 'keeps an explicit apex output format' do
      Howzit.options[:highlighter] = 'apex -t html'
      allow(util).to receive(:command_exist?).with('apex').and_return(true)

      expect(util.which_highlighter).to eq 'apex -t html --no-paginate'
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
