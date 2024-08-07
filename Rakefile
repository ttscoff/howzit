# frozen_string_literal: true

require 'bump/tasks'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'
require 'tty-spinner'
require 'rdoc/task'

Rake::RDocTask.new do |rd|
  rd.main = 'README.rdoc'
  rd.rdoc_files.include('README.rdoc', 'lib/**/*.rb', 'bin/**/*')
  rd.title = 'Howzit'
end

task default: %i[test yard]

desc 'Run test suite'
task test: %i[rubocop spec]

RSpec::Core::RakeTask.new

RuboCop::RakeTask.new do |t|
  t.formatters = ['progress']
end

YARD::Rake::YardocTask.new

desc 'Development version check'
task :ver do
  gver = `git ver`
  cver = IO.read(File.join(File.dirname(__FILE__), 'CHANGELOG.md')).match(/^#+ (\d+\.\d+\.\d+(\w+)?)/)[1]
  res = `grep VERSION lib/howzit/version.rb`
  version = res.match(/VERSION *= *['"](\d+\.\d+\.\d+(\w+)?)/)[1]
  puts "git tag: #{gver}"
  puts "version.rb: #{version}"
  puts "changelog: #{cver}"
end

desc 'Changelog version check'
task :cver do
  puts IO.read(File.join(File.dirname(__FILE__), 'CHANGELOG.md')).match(/^#+ (\d+\.\d+\.\d+(\w+)?)/)[1]
end

desc 'Run tests in Docker'
task :dockertest, :version, :login do |_, args|
  args.with_defaults(version: 'all', login: false)
  case args[:version]
  when /^a/
    %w[2 3 32].each do |v|
      Rake::Task['dockertest'].reenable
      Rake::Task['dockertest'].invoke(v, false)
    end
    Process.exit 0
  when /^32/
    img = 'howzittest32'
    file = 'docker/Dockerfile-3.2'
  when /^3/
    img = 'howzittest3'
    file = 'docker/Dockerfile-3.0'
  # when /6$/
  #   img = 'howzittest26'
  #   file = 'docker/Dockerfile-2.6'
  when /(^2|7$)/
    img = 'howzittest27'
    file = 'docker/Dockerfile-2.7'
  else
    img = 'howzittest'
    file = 'docker/Dockerfile'
  end

  d_spinner = TTY::Spinner.new("[:spinner] Setting up Docker", hide_cursor: true, format: :dots)
  d_spinner.auto_spin
  `docker build . --file #{file} -t #{img} &> /dev/null`
  d_spinner.success
  d_spinner.stop

  exec "docker run -v #{File.dirname(__FILE__)}:/howzit -it #{img} /bin/bash -l" if args[:login]

  spinner = TTY::Spinner.new("[:spinner] Running tests #{img}", hide_cursor: true, format: :dots)

  spinner.auto_spin
  res = `docker run --rm -v #{File.dirname(__FILE__)}:/howzit -it #{img}`
  commit = `bash -c "docker commit $(docker ps -a|grep #{img}|awk '{print $1}'|head -n 1) #{img}"`.strip
  if $?.exitstatus == 0
    spinner.success
  else
    spinner.error
    puts res
  end
  spinner.stop

  puts commit&.empty? ? "Error commiting Docker tag #{img}" : "Committed Docker tag #{img}"
end

desc 'Alias for build'
task package: :build

desc 'Bump incremental version number'
task :bump, :type do |_, args|
  args.with_defaults(type: 'inc')
  version_file = 'lib/howzit/version.rb'
  content = IO.read(version_file)
  content.sub!(/VERSION = '(?<major>\d+)\.(?<minor>\d+)\.(?<inc>\d+)(?<pre>\S+)?'/) do
    m = Regexp.last_match
    major = m['major'].to_i
    minor = m['minor'].to_i
    inc = m['inc'].to_i
    pre = m['pre']

    case args[:type]
    when /^maj/
      major += 1
      minor = 0
      inc = 0
    when /^min/
      minor += 1
      inc = 0
    else
      inc += 1
    end

    $stdout.puts "At version #{major}.#{minor}.#{inc}#{pre}"
    "VERSION = '#{major}.#{minor}.#{inc}#{pre}'"
  end
  File.open(version_file, 'w+') { |f| f.puts content }
end
