# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'stringio'

describe 'collected @before/@after notes' do
  let(:temp_dir) { File.expand_path(Dir.mktmpdir('howzit_notes_test')) }
  let(:out_file) { File.join(temp_dir, 'out.txt') }
  let(:child_two_command) { 'false' }
  let(:buildnote) do
    note = Howzit::BuildNote.new
    allow(note).to receive(:finalize_output)
    note
  end

  before do
    File.write(
      File.join(temp_dir, 'buildnotes.md'),
      <<~NOTE
        # Notes Project

        ## Parent

        @before
        Parent before
        @end

        @run(echo "parent" >> "#{out_file}") Parent task

        @include(Shared [prod])

        @after
        Parent after
        @end

        ### Child One

        @before
        Child before
        @end

        @run(echo "child" >> "#{out_file}") Child task

        @after
        Child after
        @end

        ### Child Two

        @run(#{child_two_command}) Child two task

        ### Child Three

        @run(echo "three" >> "#{out_file}") Three task

        @after
        Three after
        @end

        ## Shared (target)

        @run(echo "shared ${target}" >> "#{out_file}") Shared task

        @after
        Shared after ${target}
        @end
      NOTE
    )

    Dir.chdir(temp_dir)
    Howzit.instance_variable_set(:@buildnote, buildnote)
    Howzit.options[:stack] = false
    Howzit.options[:include_upstream] = false
    Howzit.options[:run] = true
    Howzit.options[:force] = false
    Howzit.options[:log_level] = 3
    Howzit.cli_args = ['parent']
    Howzit.run_log = []
    allow(Howzit::Prompt).to receive(:yn).and_return(true)
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

  def run_and_capture
    original = $stdout
    $stdout = StringIO.new
    buildnote.run
    $stdout.string.gsub(/\e\[[\d;]*m/, '')
  ensure
    $stdout = original
  end

  def positions(text, notes)
    notes.map { |note| text.index(note) }
  end

  it 'asks once for all prerequisites before running anything' do
    text = run_and_capture

    expect(Howzit::Prompt).to have_received(:yn).once
    expect(positions(text, ['Parent before', 'Child before'])).to all(be_a(Integer))
    expect(text.scan('Parent before').count).to eq 1
  end

  it 'shows all @after notes together in document order, including included topics' do
    text = run_and_capture

    notes = ['Parent after', 'Shared after prod', 'Child after', 'Three after']
    found = positions(text, notes)
    expect(found).to all(be_a(Integer))
    expect(found).to eq(found.sort)
    expect(text.scan('Child after').count).to eq 1
  end

  it 'shows notes from subtopics skipped after a failure' do
    text = run_and_capture

    expect(File.read(out_file).lines.map(&:strip)).to eq(['parent', 'shared prod', 'child'])
    expect(text).to include('Three after')
  end

  context 'when nothing fails' do
    let(:child_two_command) { 'true' }

    it 'shows the combined @after box after all tasks have run' do
      text = run_and_capture

      expect(File.read(out_file).lines.map(&:strip)).to eq(['parent', 'shared prod', 'child', 'three'])
      expect(text.scan('Parent after').count).to eq 1
    end
  end
end
