# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

describe 'includes: metadata' do
  let(:temp_dir) { File.expand_path(Dir.mktmpdir('howzit_includes_test')) }
  let(:external_dir) { File.expand_path(File.join(temp_dir, 'external_project')) }
  let(:main_dir) { File.expand_path(File.join(temp_dir, 'main_project')) }

  before do
    FileUtils.mkdir_p(external_dir)
    FileUtils.mkdir_p(main_dir)

    File.write(
      File.join(external_dir, 'buildnotes.md'),
      <<~NOTE
        # External Project

        ## Shared Topic

        @run(echo external) External task

        ## External Only

        @run(echo only_external) Only in external
      NOTE
    )

    File.write(
      File.join(main_dir, 'buildnotes.md'),
      <<~NOTE
        includes: #{external_dir}

        # Main Project

        ## Shared Topic

        @run(echo local) Local task wins

        ## Main Only

        @run(echo main) Main task
      NOTE
    )

    Dir.chdir(main_dir)
    Howzit.instance_variable_set(:@buildnote, nil)
    Howzit.options[:stack] = false
    Howzit.options[:include_upstream] = false
  end

  after do
    Dir.chdir(Dir.tmpdir)
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
    Howzit.instance_variable_set(:@buildnote, nil)
  end

  it 'loads topics from an included project directory' do
    buildnote = Howzit::BuildNote.new
    external = buildnote.find_topic('External Only')

    expect(external).not_to be_empty
    expect(external[0].title).to eq('external_project:External Only')
  end

  it 'prefers local topics over included topics with the same name' do
    buildnote = Howzit::BuildNote.new
    matches = buildnote.find_topic('Shared Topic')

    expect(matches.length).to eq(1)
    expect(matches[0].title).to eq('Shared Topic')
    expect(matches[0].tasks.first.action).to include('local')
  end

  it 'includes topics from an explicit file path' do
    shared_file = File.join(temp_dir, 'shared.md')
    File.write(
      shared_file,
      <<~NOTE
        # Shared file

        ## From File

        @run(echo from_file) From file
      NOTE
    )

    File.write(
      File.join(main_dir, 'buildnotes.md'),
      <<~NOTE
        includes: #{shared_file}

        # Main

        ## Local
      NOTE
    )

    Howzit.instance_variable_set(:@buildnote, nil)
    buildnote = Howzit::BuildNote.new
    topic = buildnote.find_topic('From File')[0]

    expect(topic.title).to eq('shared:From File')
  end

  it 'supports subtopic filters like templates' do
    File.write(
      File.join(main_dir, 'buildnotes.md'),
      <<~NOTE
        includes: #{external_dir}[External Only]

        # Main
      NOTE
    )

    Howzit.instance_variable_set(:@buildnote, nil)
    buildnote = Howzit::BuildNote.new

    expect(buildnote.find_topic('External Only')).not_to be_empty
    expect(buildnote.find_topic('Shared Topic')).to be_empty
  end
end
