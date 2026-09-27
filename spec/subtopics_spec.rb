# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

describe 'subtopics' do
  let(:temp_dir) { File.expand_path(Dir.mktmpdir('howzit_subtopics_test')) }
  let(:buildnote) { Howzit::BuildNote.new }
  let(:parent) { buildnote.find_topic('Parent')[0] }

  before do
    File.write(
      File.join(temp_dir, 'buildnotes.md'),
      <<~NOTE
        # Subtopic Project

        ## Parent

        Parent content

        @run(echo parent) Parent task

        ### Child One

        @run(echo child1) Child one task

        #### Grandchild

        @run(echo grand) Grandchild task

        ### Child Two

        @run(echo child2) Child two task

        ## Sibling

        @run(echo sibling) Sibling task
      NOTE
    )

    Dir.chdir(temp_dir)
    Howzit.instance_variable_set(:@buildnote, nil)
    Howzit.options[:stack] = false
    Howzit.options[:include_upstream] = false
  end

  after do
    Dir.chdir(Dir.tmpdir)
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
    Howzit.instance_variable_set(:@buildnote, nil)
  end

  def topic_named(title)
    buildnote.topics.find { |t| t.title == title }
  end

  it 'nests deeper headers under the preceding shallower header' do
    expect(parent.subtopics.map(&:title)).to eq(['Child One', 'Child Two'])
    expect(topic_named('Child One').subtopics.map(&:title)).to eq(['Grandchild'])
    expect(topic_named('Grandchild').ancestors.map(&:title)).to eq(['Child One', 'Parent'])
    expect(topic_named('Sibling').parent_topic).to be_nil
  end

  it 'keeps subtopics selectable on their own' do
    expect(buildnote.find_topic('Child Two')[0].title).to eq('Child Two')
  end

  it 'collects tasks from subtopics in order' do
    expect(parent.all_tasks.map(&:title)).to eq(['Parent task', 'Child one task', 'Grandchild task', 'Child two task'])
  end

  it 'displays subtopics with the parent topic' do
    output = parent.print_out.join("\n").uncolor

    expect(output).to include('Parent content')
    expect(output).to include('Child One')
    expect(output).to include('Grandchild')
    expect(output).to include('echo child2')
    expect(output).not_to include('Sibling')
  end

  it 'only outputs top-level topics when showing all topics' do
    expect(buildnote.top_level_topics.map(&:title)).to eq(%w[Parent Sibling])
  end

  it 'indents subtopics in the topic list' do
    list = buildnote.list.uncolor

    expect(list).to include("\n- Parent")
    expect(list).to include("\n  - Child One")
    expect(list).to include("\n    - Grandchild")
  end

  describe 'running a parent topic' do
    let(:ran) { [] }

    it 'runs its own tasks followed by all subtopic tasks' do
      ran_titles = ran
      allow_any_instance_of(Howzit::Task).to receive(:run) do |task|
        ran_titles << task.title
        [[], 1, true]
      end

      parent.run

      expect(ran).to eq(['Parent task', 'Child one task', 'Grandchild task', 'Child two task'])
      expect(parent.results[:total]).to eq(4)
    end

    it 'stops running subtopics after an error' do
      ran_titles = ran
      allow_any_instance_of(Howzit::Task).to receive(:run) do |task|
        ran_titles << task.title
        [[], 1, task.title != 'Child one task']
      end

      parent.run

      expect(ran).to eq(['Parent task', 'Child one task'])
      expect(parent.results[:errors]).to eq(1)
    end

    it 'continues past errors with --force' do
      Howzit.options[:force] = true
      ran_titles = ran
      allow_any_instance_of(Howzit::Task).to receive(:run) do |task|
        ran_titles << task.title
        [[], 1, task.title != 'Child one task']
      end

      parent.run

      expect(ran).to eq(['Parent task', 'Child one task', 'Grandchild task', 'Child two task'])
    ensure
      Howzit.options[:force] = false
    end
  end
end
