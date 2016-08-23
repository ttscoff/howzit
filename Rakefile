require 'bump/tasks'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

task default: [:test, :yard]

desc 'Run test suite'
task test: [:rubocop, :spec]

RSpec::Core::RakeTask.new

RuboCop::RakeTask.new do |t|
  t.formatters = ['progress']
end

YARD::Rake::YardocTask.new
