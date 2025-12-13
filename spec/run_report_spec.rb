# frozen_string_literal: true

require 'spec_helper'

describe Howzit::RunReport do
  before do
    Howzit.run_log = []
    Howzit.multi_topic_run = false
  end

  after do
    Howzit::RunReport.reset
    Howzit.multi_topic_run = false
  end

  it 'renders a simple list for single topic runs' do
    Howzit::RunReport.log({ topic: 'Git: Config', task: 'Run Git Origin', success: true, exit_status: 0 })
    plain = Howzit::RunReport.format.uncolor
    expect(plain).to include('***')
    expect(plain).to include('✅')
    expect(plain).to include('Run Git Origin')
    expect(plain).not_to include('Git: Config:')
  end

  it 'prefixes topic titles and shows failures when multiple topics run' do
    Howzit.multi_topic_run = true
    Howzit::RunReport.log({ topic: 'Git: Config', task: 'Run Git Origin', success: true, exit_status: 0 })
    Howzit::RunReport.log({ topic: 'Git: Clean Repo', task: 'Clean Git Repo', success: false, exit_status: 12 })
    plain = Howzit::RunReport.format.uncolor
    expect(plain).to include('✅')
    expect(plain).to include('Git: Config: Run Git Origin')
    expect(plain).to include('❌')
    expect(plain).to include('Git: Clean Repo: Clean Git Repo')
    expect(plain).to include('exit code 12')
  end

  it 'formats as a proper markdown table with aligned columns using format_as_table' do
    Howzit::RunReport.log({ topic: 'Test', task: 'Short', success: true, exit_status: 0 })
    Howzit::RunReport.log({ topic: 'Test', task: 'A much longer task name', success: true, exit_status: 0 })
    plain = Howzit::RunReport.format_as_table.uncolor
    lines = plain.split("\n")
    # All lines should start and end with pipe
    lines.each do |line|
      expect(line).to start_with('|')
      expect(line).to end_with('|')
    end
    # Second line should be separator
    expect(lines[1]).to match(/^\|[\s:-]+\|[\s:-]+\|$/)
  end
end

