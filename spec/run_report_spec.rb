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

  it 'renders a bordered summary for single topic runs' do
    Howzit::RunReport.log({ topic: 'Git: Config', task: 'Run Git Origin', success: true, exit_status: 0 })
    plain = Howzit::RunReport.format.uncolor
    expect(plain).to include('- [✓] Run Git Origin')
    expect(plain).not_to include('Git: Config:')
    top, line, bottom = plain.split("\n")
    expect(top).to eq('=' * line.length)
    expect(bottom).to eq('-' * line.length)
  end

  it 'prefixes topic titles and shows failures when multiple topics run' do
    Howzit.multi_topic_run = true
    Howzit::RunReport.log({ topic: 'Git: Config', task: 'Run Git Origin', success: true, exit_status: 0 })
    Howzit::RunReport.log({ topic: 'Git: Clean Repo', task: 'Clean Git Repo', success: false, exit_status: 12 })
    plain = Howzit::RunReport.format.uncolor
    expect(plain).to include('- [✓] Git: Config: Run Git Origin')
    expect(plain).to include('- [X] Git: Clean Repo: Clean Git Repo (Failed: exit code 12)')
  end
end

