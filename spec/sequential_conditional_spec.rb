# frozen_string_literal: true

require 'spec_helper'

describe 'Sequential Conditional Evaluation' do
  before do
    Howzit.options[:include_upstream] = false
    Howzit.options[:default] = true
    Howzit.options[:matching] = 'partial'
    Howzit.options[:multiple_matches] = 'choose'
    Howzit.options[:log_level] = 1
    Howzit.named_arguments = {}
  end

  after do
    FileUtils.rm_f('builda.md')
    Howzit.named_arguments = {}
  end

  describe 'variables set in run blocks affecting conditionals' do
    it 'allows @if blocks to use variables set in preceding run blocks' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        ```run Set Variable
        #!/bin/bash
        echo "VAR:TEST_VAR=success" >> "$HOWZIT_COMM_FILE"
        ```

        @if ${TEST_VAR} == "success"
        @run(echo "Conditional task executed") Conditional Task
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote.find_topic('Test Topic')[0]
      expect(topic).not_to be_nil

      # Verify the conditional task is present
      expect(topic.directives).not_to be_nil
      expect(topic.directives.any?(&:conditional?)).to be true

      # Run the topic and verify the conditional task executes
      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      # Track which tasks actually run
      task_titles = []
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        task_titles << task.title if task.respond_to?(:title) && task.title
        method.call
      end

      topic.run

      # The conditional task should have been executed
      expect(task_titles).to include('Conditional Task')
    end

    it 'does not execute @if blocks when variable condition is false' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        ```run Set Variable
        #!/bin/bash
        echo "VAR:TEST_VAR=failure" >> "$HOWZIT_COMM_FILE"
        ```

        @if ${TEST_VAR} == "success"
        @run(echo "This should not run") Hidden Task
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote.find_topic('Test Topic')[0]

      task_titles = []
      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      # Track which tasks actually run
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        task_titles << task.title if task.respond_to?(:title) && task.title
        method.call
      end

      topic.run

      # The conditional task should NOT have been executed
      expect(task_titles).not_to include('Hidden Task')
    end

    it 're-evaluates conditionals after each task execution' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        ```run Set First Variable
        #!/bin/bash
        echo "VAR:STEP=1" >> "$HOWZIT_COMM_FILE"
        ```

        @if ${STEP} == "1"
        @run(echo "VAR:STEP=2" >> "$HOWZIT_COMM_FILE") Update Step
        @end

        @if ${STEP} == "2"
        @run(echo "Final step") Final Task
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote.find_topic('Test Topic')[0]

      task_titles = []
      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      # Track which tasks actually run
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        task_titles << task.title if task.respond_to?(:title) && task.title
        method.call
      end

      topic.run

      # Both conditional tasks should execute
      expect(task_titles).to include('Update Step')
      expect(task_titles).to include('Final Task')
    end

    it 'handles @unless blocks with variables from run blocks' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        ```run Set Variable
        #!/bin/bash
        echo "VAR:STATUS=ready" >> "$HOWZIT_COMM_FILE"
        ```

        @unless ${STATUS} == "not_ready"
        @run(echo "Status is ready") Ready Task
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote.find_topic('Test Topic')[0]

      task_titles = []
      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      # Track which tasks actually run
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        task_titles << task.title if task.respond_to?(:title) && task.title
        method.call
      end

      topic.run

      expect(task_titles).to include('Ready Task')
    end

    it 'handles @elsif blocks with variables from run blocks' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        ```run Set Variable
        #!/bin/bash
        echo "VAR:VALUE=two" >> "$HOWZIT_COMM_FILE"
        ```

        @if ${VALUE} == "one"
        @run(echo "Value is one") One Task
        @elsif ${VALUE} == "two"
        @run(echo "Value is two") Two Task
        @else
        @run(echo "Value is other") Other Task
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote.find_topic('Test Topic')[0]

      task_titles = []
      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      # Track which tasks actually run
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        task_titles << task.title if task.respond_to?(:title) && task.title
        method.call
      end

      topic.run

      expect(task_titles).to include('Two Task')
      expect(task_titles).not_to include('One Task')
      expect(task_titles).not_to include('Other Task')
    end

    it 'handles @else blocks with variables from run blocks' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        ```run Set Variable
        #!/bin/bash
        echo "VAR:VALUE=other" >> "$HOWZIT_COMM_FILE"
        ```

        @if ${VALUE} == "one"
        @run(echo "Value is one") One Task
        @else
        @run(echo "Value is other") Other Task
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote.find_topic('Test Topic')[0]

      task_titles = []
      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      # Track which tasks actually run
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        task_titles << task.title if task.respond_to?(:title) && task.title
        method.call
      end

      topic.run

      expect(task_titles).to include('Other Task')
      expect(task_titles).not_to include('One Task')
    end
  end

  describe 'variables set in run blocks available in subsequent run blocks' do
    it 'makes variables set in one run block available to subsequent run blocks' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        ```run Set Variable
        #!/bin/bash
        echo "VAR:SHARED_VAR=test_value" >> "$HOWZIT_COMM_FILE"
        ```

        ```run Use Variable
        #!/bin/bash
        set_var VERIFIED "true"
        ```
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote.find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      # Actually run the tasks to set variables
      topic.run

      # Verify the variables were set and available
      expect(Howzit.named_arguments['SHARED_VAR']).to eq('test_value')
      expect(Howzit.named_arguments['VERIFIED']).to eq('true')
    end

    it 'allows multiple run blocks to set and use variables sequentially' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        ```run First Block
        #!/bin/bash
        echo "VAR:FIRST=1" >> "$HOWZIT_COMM_FILE"
        ```

        ```run Second Block
        #!/bin/bash
        set_var SECOND "2"
        set_var COMBINED "12"
        ```

        ```run Third Block
        #!/bin/bash
        set_var THIRD "3"
        set_var ALL "123"
        ```
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote.find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      # Actually run the tasks to set variables sequentially
      topic.run

      expect(Howzit.named_arguments['FIRST']).to eq('1')
      expect(Howzit.named_arguments['SECOND']).to eq('2')
      expect(Howzit.named_arguments['COMBINED']).to eq('12')
      expect(Howzit.named_arguments['THIRD']).to eq('3')
      expect(Howzit.named_arguments['ALL']).to eq('123')
    end
  end
end
