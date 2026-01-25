# frozen_string_literal: true

require 'spec_helper'

# https://github.com/thoiberg/cli-test
describe 'CLI' do
  include CliTest

  before do
    # Temporarily rename buildnotes.md so builda.md is selected
    @original_buildnotes = 'buildnotes.md'
    @backup_buildnotes = 'buildnotes.md.backup'
    FileUtils.mv(@original_buildnotes, @backup_buildnotes) if File.exist?(@original_buildnotes)
  end

  after do
    # Restore buildnotes.md
    FileUtils.mv(@backup_buildnotes, @original_buildnotes) if File.exist?(@backup_buildnotes)
  end

  it 'executes successfully' do
    execute_script('bin/howzit', use_bundler: true)
    expect(last_execution).to be_successful
  end

  it 'lists available topics' do
    execute_script('bin/howzit', use_bundler: true, args: %w[--no-stack -L])
    expect(last_execution).to be_successful
    expect(last_execution.stdout).to match(/Topic Balogna/)
    expect(last_execution.stdout.split(/\n/).count).to eq 7
  end

  it 'lists available tasks' do
    execute_script('bin/howzit', use_bundler: true, args: %w[--no-stack -T])
    expect(last_execution).to be_successful
    expect(last_execution.stdout).to match(/Topic Balogna/)
    expect(last_execution.stdout.split(/\n/).count).to eq 2
  end
end
