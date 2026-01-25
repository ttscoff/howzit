# frozen_string_literal: true

require 'spec_helper'

describe '@set_var directive' do
  before do
    Howzit.options[:include_upstream] = false
    Howzit.options[:stack] = false
    Howzit.options[:default] = true
    Howzit.options[:matching] = 'partial'
    Howzit.options[:multiple_matches] = 'choose'
    Howzit.options[:log_level] = 1
    Howzit.options[:run] = true
    Howzit.named_arguments = {}
  end

  after do
    FileUtils.rm_f('builda.md')
    Howzit.named_arguments = {}
  end

  describe 'parsing @set_var directives' do
    it 'parses @set_var directive with simple string value' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(VERSION, "1.2.3")
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      expect(topic.directives).not_to be_nil
      set_var_directive = topic.directives.find(&:set_var?)
      expect(set_var_directive).not_to be_nil
      expect(set_var_directive.var_name).to eq('VERSION')
      expect(set_var_directive.var_value).to eq('1.2.3')
    end

    it 'parses @set_var directive with unquoted value' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(STATUS, success)
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      set_var_directive = topic.directives.find(&:set_var?)
      expect(set_var_directive).not_to be_nil
      expect(set_var_directive.var_name).to eq('STATUS')
      expect(set_var_directive.var_value).to eq('success')
    end

    it 'parses @set_var directive with value containing commas' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(MESSAGE, Hello, world)
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      set_var_directive = topic.directives.find(&:set_var?)
      expect(set_var_directive).not_to be_nil
      expect(set_var_directive.var_name).to eq('MESSAGE')
      expect(set_var_directive.var_value).to eq('Hello, world')
    end

    it 'parses @set_var directive with command substitution using backticks' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(VERSION, `echo "1.2.3"`)
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      set_var_directive = topic.directives.find(&:set_var?)
      expect(set_var_directive).not_to be_nil
      expect(set_var_directive.var_name).to eq('VERSION')
      expect(set_var_directive.var_value).to eq('`echo "1.2.3"`')
    end

    it 'parses @set_var directive with command substitution using $()' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(DATE, $(date +%Y-%m-%d))
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      set_var_directive = topic.directives.find(&:set_var?)
      expect(set_var_directive).not_to be_nil
      expect(set_var_directive.var_name).to eq('DATE')
      expect(set_var_directive.var_value).to eq('$(date +%Y-%m-%d)')
    end

    it 'rejects invalid variable names with spaces' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(INVALID NAME, value)
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      set_var_directive = topic.directives.find(&:set_var?)
      expect(set_var_directive).to be_nil
    end

    it 'accepts variable names with dashes and underscores' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(MY-VAR_NAME, value)
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      set_var_directive = topic.directives.find(&:set_var?)
      expect(set_var_directive).not_to be_nil
      expect(set_var_directive.var_name).to eq('MY-VAR_NAME')
    end
  end

  describe 'setting variables with @set_var' do
    it 'sets a variable with a simple string value' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(VERSION, "1.2.3")
        @run(echo "Version is ${VERSION}")
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      output = []
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        if task.action && task.action.include?('echo')
          output << task.action
        end
        method.call
      end

      topic.run

      expect(Howzit.named_arguments['VERSION']).to eq('1.2.3')
      expect(output.any? { |o| o.include?('Version is 1.2.3') }).to be true
    end

    it 'sets a variable with an unquoted value' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(STATUS, success)
        @run(echo "Status: ${STATUS}")
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)
      topic.run

      expect(Howzit.named_arguments['STATUS']).to eq('success')
    end

    it 'removes quotes from quoted values' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(MESSAGE, "Hello, world")
        @set_var(OTHER, 'Single quotes')
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)
      topic.run

      expect(Howzit.named_arguments['MESSAGE']).to eq('Hello, world')
      expect(Howzit.named_arguments['OTHER']).to eq('Single quotes')
    end

    it 'sets multiple variables in sequence' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(FIRST, "1")
        @set_var(SECOND, "2")
        @set_var(THIRD, "3")
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)
      topic.run

      expect(Howzit.named_arguments['FIRST']).to eq('1')
      expect(Howzit.named_arguments['SECOND']).to eq('2')
      expect(Howzit.named_arguments['THIRD']).to eq('3')
    end

    it 'allows variable substitution in values' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(BASE, "1.2")
        @set_var(VERSION, "${BASE}.3")
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)
      topic.run

      expect(Howzit.named_arguments['BASE']).to eq('1.2')
      expect(Howzit.named_arguments['VERSION']).to eq('1.2.3')
    end
  end

  describe 'command substitution in @set_var' do
    it 'executes command with backticks and uses output as value' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(VERSION, `echo "1.2.3"`)
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)
      topic.run

      expect(Howzit.named_arguments['VERSION']).to eq('1.2.3')
    end

    it 'executes command with $() syntax and uses output as value' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(VERSION, $(echo "1.2.3"))
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)
      topic.run

      expect(Howzit.named_arguments['VERSION']).to eq('1.2.3')
    end

    it 'strips whitespace from command output' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(VERSION, `echo "  1.2.3  "`)
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)
      topic.run

      expect(Howzit.named_arguments['VERSION']).to eq('1.2.3')
    end

    it 'allows variable substitution in command' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(BASE, "1.2")
        @set_var(VERSION, `echo "${BASE}.3"`)
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)
      topic.run

      expect(Howzit.named_arguments['VERSION']).to eq('1.2.3')
    end

    it 'handles command execution errors gracefully' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(VERSION, `nonexistent-command-that-fails`)
        @run(echo "test")
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)

      # Set up console mock before topic is created (since gather_tasks runs during initialization)
      console_warnings = []
      allow(Howzit.console).to receive(:warn) do |message|
        console_warnings << message
      end

      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)
      topic.run

      expect(Howzit.named_arguments['VERSION']).to eq('')
      expect(console_warnings.any? { |w| w =~ /Error executing command in @set_var/ }).to be true
    end
  end

  describe 'using @set_var variables in conditionals' do
    it 'allows @if blocks to use variables set with @set_var' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(STATUS, "success")
        @if ${STATUS} == "success"
        @run(echo "Conditional executed") Conditional Task
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      task_titles = []
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        task_titles << task.title if task.respond_to?(:title) && task.title
        method.call
      end

      topic.run

      # Variable should be set during execution and task should run
      # Note: Variable may not persist after run completes in sequential path
      # but it should be available during execution
      expect(task_titles).to include('Conditional Task')
    end

    it 'does not execute @if blocks when variable condition is false' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(STATUS, "failure")
        @if ${STATUS} == "success"
        @run(echo "This should not run") Hidden Task
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      task_titles = []
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        task_titles << task.title if task.respond_to?(:title) && task.title
        method.call
      end

      topic.run

      expect(task_titles).not_to include('Hidden Task')
    end

    it 'allows @elsif and @else blocks to use @set_var variables' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(STATUS, "warning")
        @if ${STATUS} == "success"
        @run(echo "Success") Success Task
        @elsif ${STATUS} == "warning"
        @run(echo "Warning") Warning Task
        @else
        @run(echo "Other") Other Task
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      task_titles = []
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        task_titles << task.title if task.respond_to?(:title) && task.title
        method.call
      end

      topic.run

      expect(task_titles).to include('Warning Task')
      expect(task_titles).not_to include('Success Task')
      expect(task_titles).not_to include('Other Task')
    end

    it 're-evaluates conditionals after @set_var changes variables' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(STATUS, "initial")
        @if ${STATUS} == "initial"
        @run(echo "Initial state") Initial Task
        @set_var(STATUS, "updated")
        @end
        @if ${STATUS} == "updated"
        @run(echo "Updated state") Updated Task
        @end
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      task_titles = []
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        task_titles << task.title if task.respond_to?(:title) && task.title
        method.call
      end

      topic.run

      expect(task_titles).to include('Initial Task')
      expect(task_titles).to include('Updated Task')
      expect(Howzit.named_arguments['STATUS']).to eq('updated')
    end
  end

  describe 'using @set_var variables in @run directives' do
    it 'substitutes variables in @run command' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(VERSION, "1.2.3")
        @set_var(FILE, "test.txt")
        @run(echo "Version ${VERSION} in ${FILE}")
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      output = []
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        output << task.action if task.action
        method.call
      end

      topic.run

      expect(output.any? { |o| o.include?('Version 1.2.3 in test.txt') }).to be true
    end

    it 'substitutes variables from command substitution in @run' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(VERSION, `echo "1.2.3"`)
        @run(echo "Built version ${VERSION}")
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      output = []
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        output << task.action if task.action
        method.call
      end

      topic.run

      expect(Howzit.named_arguments['VERSION']).to eq('1.2.3')
      expect(output.any? { |o| o.include?('Built version 1.2.3') }).to be true
    end
  end

  describe 'non-sequential execution path' do
    it 'processes @set_var directives before tasks when no conditionals present' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(VERSION, "1.2.3")
        @run(echo "Version ${VERSION}")
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)

      output = []
      allow_any_instance_of(Howzit::Task).to receive(:run).and_wrap_original do |method|
        task = method.receiver
        output << task.action if task.action
        method.call
      end

      topic.run

      expect(Howzit.named_arguments['VERSION']).to eq('1.2.3')
      expect(output.any? { |o| o.include?('Version 1.2.3') }).to be true
    end

    it 'processes multiple @set_var directives in non-sequential path' do
      note = <<~EONOTE
        # Test

        ## Test Topic

        @set_var(FIRST, "1")
        @set_var(SECOND, "2")
        @run(echo "${FIRST} and ${SECOND}")
      EONOTE
      File.open('builda.md', 'w') { |f| f.puts note }
      Howzit.instance_variable_set(:@buildnote, nil)
      topic = Howzit.buildnote('builda.md').find_topic('Test Topic')[0]

      allow(Howzit::Prompt).to receive(:yn).and_return(true)
      topic.run

      expect(Howzit.named_arguments['FIRST']).to eq('1')
      expect(Howzit.named_arguments['SECOND']).to eq('2')
    end
  end
end
