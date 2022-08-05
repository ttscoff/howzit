# frozen_string_literal: true

require 'spec_helper'

# https://github.com/thoiberg/cli-test
describe 'CLI' do
  include CliTest

  it 'executes successfully' do
    execute_script('bin/howzit', use_bundler: true)
    expect(last_execution).to be_successful
  end

  it 'lists available topics' do
    execute_script('bin/howzit', use_bundler: true, args: %w[-L])
    expect(last_execution).to be_successful
    expect(last_execution.stdout).to match(/Topic Balogna/)
    expect(last_execution.stdout.split(/\n/).count).to eq 3
  end

  it 'lists available tasks' do
    execute_script('bin/howzit', use_bundler: true, args: %w[-T])
    expect(last_execution).to be_successful
    expect(last_execution.stdout).to match(/Topic Balogna/)
    expect(last_execution.stdout.split(/\n/).count).to eq 2
  end
end
