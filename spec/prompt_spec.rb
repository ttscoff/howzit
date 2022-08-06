# frozen_string_literal: true

require 'spec_helper'

describe Howzit::Prompt do
  subject(:prompt) { Howzit::Prompt }

  describe '.yn' do
    it 'returns default response' do
      Howzit.options[:default] = true
      expect(prompt.yn('Test prompt', default: true)).to be_truthy
      expect(prompt.yn('Test prompt', default: false)).not_to be_truthy
    end
  end

  describe '.color_single_options' do
    it 'returns uncolored string' do
      Howzit::Color.coloring = false
      expect(prompt.color_single_options(%w[y n])).to eq "[y/n]"
    end
  end

  describe '.options_list' do
    it 'creates a formatted list of options' do
      options = %w[one two three four five].each_with_object([]) do |x, arr|
        arr << "Option item #{x}"
      end
      expect { prompt.options_list(options) }.to output(/ 2 \) Option item two/).to_stdout
    end
  end

  describe '.choose' do
    it 'returns a single match' do
      expect(prompt.choose(['option 1']).count).to eq 1
    end
  end
end
