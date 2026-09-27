# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

describe 'shell variable handling' do
  before do
    Howzit.arguments = []
    Howzit.named_arguments = { 'file' => 'README.md', 'version' => '1.2.3' }
  end

  after do
    Howzit.arguments = []
    Howzit.named_arguments = {}
  end

  describe 'String#render_arguments' do
    it 'substitutes Howzit variables' do
      expect('v${version}'.render_arguments).to eq('v1.2.3')
    end

    it 'leaves unknown variables for the shell' do
      expect('echo "${HOME}"'.render_arguments).to eq('echo "${HOME}"')
    end

    it 'uses Howzit-style defaults for undefined variables' do
      expect('${missing:fallback}'.render_arguments).to eq('fallback')
      expect('${url:http://localhost:3000}'.render_arguments).to eq('http://localhost:3000')
    end

    it 'leaves shell parameter expansions alone' do
      %w[${OUT:-/tmp} ${OUT:=/tmp} ${OUT:+set} ${OUT:?missing} ${NAME:0:3} ${#NAME} ${NAME/a/b}].each do |expansion|
        expect(expansion.render_arguments).to eq(expansion)
      end
    end

    it 'substitutes a defined Howzit variable in ${VAR:-default}' do
      expect('${version:-0.0.0}'.render_arguments).to eq('1.2.3')
    end

    it 'leaves positional placeholders without a matching argument' do
      expect('f() { echo "$1 ${2}"; }'.render_arguments).to eq('f() { echo "$1 ${2}"; }')
      expect("awk '{print $1}'".render_arguments).to eq("awk '{print $1}'")
    end

    it 'leaves $@ and $* alone when no arguments were passed' do
      expect('run() { "$@"; }'.render_arguments).to eq('run() { "$@"; }')
    end

    it 'substitutes positional arguments when passed' do
      Howzit.arguments = ['one', 'two words']
      expect('$1 ${2} ${3:three}'.render_arguments).to eq('one two words three')
      expect('cmd $@'.render_arguments).to eq("cmd one two\\ words")
    end

    it 'leaves escaped $${VAR} placeholders until execution' do
      rendered = 'echo $${file}'.render_arguments
      expect(rendered).to eq('echo $${file}')
      expect(rendered.unescape_placeholders).to eq('echo ${file}')
    end
  end

  describe 'String#shellify_defaults' do
    it 'converts Howzit defaults to shell defaults' do
      expect('${name:world} ${1:first}'.shellify_defaults).to eq('${name:-world} ${1:-first}')
    end

    it 'leaves shell expansions alone' do
      %w[${name} ${name:-x} ${name:0:3} ${name:$offset} ${name: -2}].each do |expansion|
        expect(expansion.shellify_defaults).to eq(expansion)
      end
    end
  end

  describe 'ScriptSupport.shell_script?' do
    it 'detects shell scripts' do
      expect(Howzit::ScriptSupport.shell_script?("echo hi\n")).to be true
      expect(Howzit::ScriptSupport.shell_script?("#!/bin/bash\necho hi\n")).to be true
      expect(Howzit::ScriptSupport.shell_script?("#!/usr/bin/env zsh\n")).to be true
      expect(Howzit::ScriptSupport.shell_script?("#!/bin/sh -e\n")).to be true
    end

    it 'excludes other interpreters' do
      expect(Howzit::ScriptSupport.shell_script?("#!/usr/bin/env ruby\n")).to be false
      expect(Howzit::ScriptSupport.shell_script?("#!/usr/bin/env fish\n")).to be false
      expect(Howzit::ScriptSupport.shell_script?("#!/usr/bin/env python3\n")).to be false
    end
  end

  describe 'running blocks' do
    let(:temp_dir) { File.expand_path(Dir.mktmpdir('howzit_shell_vars_test')) }
    let(:out_file) { File.join(temp_dir, 'out.txt') }

    before do
      File.write(
        File.join(temp_dir, 'buildnotes.md'),
        <<~NOTE
          # Shell Variables

          ## Shell Block (target:prod)

          ```run
          #!/bin/bash
          greet() { echo "arg=$1"; }
          for file in a.rb; do echo "loop=${file}"; done > "#{out_file}"
          echo "howzit=${target}" >> "#{out_file}"
          echo "default=${undefined_var:fallback}" >> "#{out_file}"
          echo "shell_default=${UNSET_THING:-shellval}" >> "#{out_file}"
          echo "env=${HOWZIT_SPEC_ENV}" >> "#{out_file}"
          greet hello >> "#{out_file}"
          echo "script_arg=${1:-none}" >> "#{out_file}"
          ```

          ## Escaped Run

          @run(echo "$${HOWZIT_SPEC_ENV}" > "#{out_file}") Escaped
        NOTE
      )

      ENV['HOWZIT_SPEC_ENV'] = 'from_env'
      Dir.chdir(temp_dir)
      Howzit.instance_variable_set(:@buildnote, nil)
      Howzit.options[:stack] = false
      Howzit.options[:include_upstream] = false
      Howzit.options[:log_level] = 3
      Howzit.named_arguments = { 'file' => 'README.md' }
    end

    after do
      ENV.delete('HOWZIT_SPEC_ENV')
      Howzit.options[:shell_variables] = 'env'
      Howzit.options[:log_level] = 1
      Dir.chdir(Dir.tmpdir)
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      Howzit.instance_variable_set(:@buildnote, nil)
    end

    def output_lines
      File.read(out_file).lines.map(&:strip)
    end

    it 'passes Howzit variables to shell blocks through the environment' do
      Howzit::BuildNote.new.find_topic('Shell Block')[0].run

      expect(output_lines).to eq([
                                   'loop=a.rb',
                                   'howzit=prod',
                                   'default=fallback',
                                   'shell_default=shellval',
                                   'env=from_env',
                                   'arg=hello',
                                   'script_arg=none'
                                 ])
    end

    it 'passes positional arguments to the script' do
      Howzit.arguments = ['cli_arg']
      Howzit::BuildNote.new.find_topic('Shell Block')[0].run

      expect(output_lines).to include('arg=hello', 'script_arg=cli_arg')
    end

    it 'uses text substitution when shell_variables is substitute' do
      Howzit.options[:shell_variables] = 'substitute'
      Howzit::BuildNote.new.find_topic('Shell Block')[0].run

      expect(output_lines).to include('loop=README.md', 'howzit=prod')
    end

    it 'passes escaped placeholders to the shell in @run commands' do
      Howzit::BuildNote.new.find_topic('Escaped Run')[0].run

      expect(output_lines).to eq(['from_env'])
    end
  end
end
