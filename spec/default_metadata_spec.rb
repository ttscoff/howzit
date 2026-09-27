# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

describe 'default: metadata' do
  let(:temp_dir) { File.expand_path(Dir.mktmpdir('howzit_default_test')) }
  let(:out_file) { File.join(temp_dir, 'out.txt') }
  let(:default_line) { 'default: Build, Deploy[prod, fast], Test' }
  let(:buildnote) do
    note = Howzit::BuildNote.new
    allow(note).to receive(:finalize_output)
    note
  end

  before do
    File.write(
      File.join(temp_dir, 'buildnotes.md'),
      <<~NOTE
        #{default_line}

        # Default Project

        ## Build

        @run(echo "build" >> "#{out_file}") Build it

        ## Deploy (target, speed:slow)

        @run(echo "deploy ${target} ${speed}" >> "#{out_file}") Deploy it

        ## Test

        @run(echo "test" >> "#{out_file}") Test it

        ## Broken

        @run(false) Fail

        ## Release

        @include(Deploy [staging])
        @include(Deploy [prod, fast])
      NOTE
    )

    Dir.chdir(temp_dir)
    Howzit.instance_variable_set(:@buildnote, buildnote)
    Howzit.options[:stack] = false
    Howzit.options[:include_upstream] = false
    Howzit.options[:run] = true
    Howzit.options[:force] = false
    Howzit.options[:log_level] = 3
    Howzit.cli_args = []
    Howzit.run_log = []
  end

  after do
    Howzit.options[:run] = false
    Howzit.options[:log_level] = 1
    Howzit.cli_args = []
    Howzit.run_log = []
    Dir.chdir(Dir.tmpdir)
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
    Howzit.instance_variable_set(:@buildnote, nil)
  end

  def output_lines
    File.read(out_file).lines.map(&:strip)
  end

  describe 'parsing' do
    it 'splits topics on commas outside of brackets' do
      expect(buildnote.send(:parse_default_metadata, 'Build, Deploy[prod, fast],Test')).to eq(
        ['Build', 'Deploy[prod, fast]', 'Test']
      )
    end

    it 'separates bracketed arguments from the topic name' do
      expect(buildnote.send(:parse_topic_with_args, 'Deploy[prod, fast]')).to eq(['Deploy', 'prod, fast'])
      expect(buildnote.send(:parse_topic_with_args, 'Build')).to eq(['Build', nil])
    end
  end

  describe 'running' do
    it 'runs the default topics in order with howzit -r' do
      buildnote.run

      expect(output_lines).to eq(['build', 'deploy prod fast', 'test'])
    end

    it 'runs the default topics with howzit -r default' do
      Howzit.cli_args = ['default']
      buildnote.run

      expect(output_lines).to eq(['build', 'deploy prod fast', 'test'])
    end

    context 'with fewer arguments than the topic accepts' do
      let(:default_line) { 'default: Deploy[prod]' }

      it 'uses the topic defaults for the rest' do
        buildnote.run

        expect(output_lines).to eq(['deploy prod slow'])
      end
    end

    context 'with a missing topic' do
      let(:default_line) { 'default: Build, Nonexistent, Test' }

      it 'runs the topics that match' do
        buildnote.run

        expect(output_lines).to eq(%w[build test])
      end
    end

    context 'with a failing topic' do
      let(:default_line) { 'default: Build, Broken, Test' }

      it 'stops after the failure and skips the remaining topics' do
        buildnote.run

        expect(output_lines).to eq(['build'])
        expect(Howzit.run_log.map { |e| [e[:task], e[:skipped] ? :skipped : e[:success]] }).to eq(
          [['Build it', true], ['Fail', false], ['Test it', :skipped]]
        )
      end
    end
  end

  describe '@include with bracketed arguments' do
    it 'binds the arguments to the included topic for each include' do
      Howzit.cli_args = ['release']
      buildnote.run

      expect(output_lines).to eq(['deploy staging slow', 'deploy prod fast'])
    end
  end
end
