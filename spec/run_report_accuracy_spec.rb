# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

describe 'run report accuracy' do
  let(:temp_dir) { File.expand_path(Dir.mktmpdir('howzit_run_report_test')) }
  let(:buildnote) { Howzit::BuildNote.new }

  before do
    File.write(
      File.join(temp_dir, 'buildnotes.md'),
      <<~NOTE
        # Run Report Project

        ## Failing

        @run(true) First
        @run(false) Second
        @run(true) Third

        ## Release

        @include(Failing)
        @run(true) After include

        ## Early Failure

        @run(false) Fails first
        @include(Failing)

        ## Conditional

        @if 1 == 1
        @run(false) Conditional failure
        @run(true) Conditional after
        @end
        @run(true) Unconditional after

        ## Parent

        @run(true) Parent task

        ### Broken Child

        @run(false) Child failure
        @run(true) Child after

        ### Later Child

        @run(true) Later child task
      NOTE
    )

    Dir.chdir(temp_dir)
    Howzit.instance_variable_set(:@buildnote, buildnote)
    Howzit.options[:stack] = false
    Howzit.options[:include_upstream] = false
    Howzit.options[:run] = true
    Howzit.options[:force] = false
    Howzit.run_log = []
  end

  after do
    Howzit.options[:run] = false
    Howzit.options[:force] = false
    Howzit.run_log = []
    Dir.chdir(Dir.tmpdir)
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
    Howzit.instance_variable_set(:@buildnote, nil)
  end

  def report
    Howzit.run_log.map do |entry|
      status = if entry[:skipped]
                 :skipped
               else
                 entry[:success] ? :ok : :failed
               end
      [entry[:task], status]
    end
  end

  it 'logs the failed task and marks the rest as skipped' do
    buildnote.find_topic('Failing')[0].run

    expect(report).to eq([['First', :ok], ['Second', :failed], ['Third', :skipped]])
    expect(Howzit.run_log[1][:exit_status]).to eq(1)
  end

  it 'treats a failed include as a failure and skips the rest of the including topic' do
    topic = buildnote.find_topic('Release')[0]
    topic.run

    expect(report).to eq([['First', :ok], ['Second', :failed], ['Third', :skipped], ['After include', :skipped]])
    expect(topic.results).to include(total: 2, success: 1, errors: 1)
  end

  it 'expands skipped includes into the included topic tasks' do
    buildnote.find_topic('Early Failure')[0].run

    expect(report).to eq([['Fails first', :failed], ['First', :skipped], ['Second', :skipped], ['Third', :skipped]])
    expect(Howzit.run_log[1][:topic]).to eq('Failing')
  end

  it 'skips only unconditional tasks after a failure in a conditional topic' do
    buildnote.find_topic('Conditional')[0].run

    expect(report).to eq([['Conditional failure', :failed], ['Unconditional after', :skipped]])
  end

  it 'skips remaining subtopics after a subtopic fails' do
    buildnote.find_topic('Parent')[0].run

    expect(report).to eq([
                           ['Parent task', :ok],
                           ['Child failure', :failed],
                           ['Child after', :skipped],
                           ['Later child task', :skipped]
                         ])
    expect(Howzit.run_log.last[:topic]).to eq('Later Child')
  end

  it 'continues past failures with --force and logs every result' do
    Howzit.options[:force] = true
    topic = buildnote.find_topic('Release')[0]
    topic.run

    expect(report).to eq([['First', :ok], ['Second', :failed], ['Third', :ok], ['After include', :ok]])
    expect(topic.results).to include(total: 4, success: 3, errors: 1)
  end

  describe 'multi-topic runs' do
    before do
      allow(buildnote).to receive(:finalize_output)
    end

    let(:topics) { ['Failing', 'Parent'].map { |title| buildnote.find_topic(title)[0] } }

    it 'stops after a topic fails and skips the remaining topics' do
      buildnote.send(:process_topic_matches, topics, [])

      expect(report).to eq([
                             ['First', :ok],
                             ['Second', :failed],
                             ['Third', :skipped],
                             ['Parent task', :skipped],
                             ['Child failure', :skipped],
                             ['Child after', :skipped],
                             ['Later child task', :skipped]
                           ])
    end

    it 'runs every topic with --force' do
      Howzit.options[:force] = true
      buildnote.send(:process_topic_matches, topics, [])

      expect(report.map(&:first)).to include('Parent task', 'Later child task')
      expect(report.map(&:last)).not_to include(:skipped)
    end
  end

  it 'formats skipped tasks in the report' do
    buildnote.find_topic('Failing')[0].run
    plain = Howzit::RunReport.format.uncolor

    expect(plain).to include('❌ Second  (exit code 1)')
    expect(plain).to include('⏭️ Third (skipped)')
  end
end
