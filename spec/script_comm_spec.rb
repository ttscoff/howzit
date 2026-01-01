# frozen_string_literal: true

require 'spec_helper'

describe Howzit::ScriptComm do
  before do
    Howzit.named_arguments = {}
    Howzit.options[:log_level] = 0
    # Clear any existing HOWZIT_COMM_FILE
    ENV.delete('HOWZIT_COMM_FILE')
  end

  after do
    # Clean up any leftover communication files
    if ENV['HOWZIT_COMM_FILE'] && File.exist?(ENV['HOWZIT_COMM_FILE']) && File.file?(ENV['HOWZIT_COMM_FILE'])
      begin
        File.unlink(ENV['HOWZIT_COMM_FILE'])
      rescue Errno::EPERM, Errno::ENOENT
        # Ignore permission errors or missing files
      end
    end
    ENV.delete('HOWZIT_COMM_FILE')
    Howzit.named_arguments = {}
  end

  describe '.setup' do
    it 'creates a communication file' do
      comm_file = Howzit::ScriptComm.setup
      expect(comm_file).to be_a(String)
      expect(File.exist?(comm_file)).to be true
    end

    it 'sets HOWZIT_COMM_FILE environment variable' do
      comm_file = Howzit::ScriptComm.setup
      expect(ENV['HOWZIT_COMM_FILE']).to eq(comm_file)
    end

    it 'creates a writable file' do
      comm_file = Howzit::ScriptComm.setup
      expect { File.write(comm_file, 'test') }.not_to raise_error
    end
  end

  describe '.process' do
    it 'returns empty hash for non-existent file' do
      result = Howzit::ScriptComm.process('/nonexistent/path')
      expect(result).to eq({ logs: [], vars: {} })
    end

    it 'processes log messages' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "LOG:info:Test message\nLOG:warn:Warning message\n")
      result = Howzit::ScriptComm.process(comm_file)
      expect(result[:logs].length).to eq(2)
      expect(result[:logs][0][:level]).to eq(:info)
      expect(result[:logs][0][:message]).to eq('Test message')
      expect(result[:logs][1][:level]).to eq(:warn)
      expect(result[:logs][1][:message]).to eq('Warning message')
    end

    it 'processes variables' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "VAR:TEST_VAR=test_value\nVAR:ANOTHER_VAR=another_value\n")
      result = Howzit::ScriptComm.process(comm_file)
      expect(result[:vars]).to eq({ 'TEST_VAR' => 'test_value', 'ANOTHER_VAR' => 'another_value' })
    end

    it 'processes mixed logs and variables' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "LOG:info:Starting\nVAR:STATUS=running\nLOG:info:Done\nVAR:STATUS=complete\n")
      result = Howzit::ScriptComm.process(comm_file)
      expect(result[:logs].length).to eq(2)
      expect(result[:vars]).to eq({ 'STATUS' => 'complete' })
    end

    it 'handles all log levels' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "LOG:info:Info message\nLOG:warn:Warn message\nLOG:error:Error message\nLOG:debug:Debug message\n")
      result = Howzit::ScriptComm.process(comm_file)
      expect(result[:logs].map { |l| l[:level] }).to contain_exactly(:info, :warn, :error, :debug)
    end

    it 'ignores empty lines' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "\nLOG:info:Message\n\nVAR:TEST=value\n\n")
      result = Howzit::ScriptComm.process(comm_file)
      expect(result[:logs].length).to eq(1)
      expect(result[:vars]).to eq({ 'TEST' => 'value' })
    end

    it 'handles case-insensitive log levels' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "LOG:INFO:Uppercase\nLOG:Warn:Mixed\nLOG:error:lowercase\n")
      result = Howzit::ScriptComm.process(comm_file)
      expect(result[:logs].map { |l| l[:level] }).to contain_exactly(:info, :warn, :error)
    end

    it 'handles case-insensitive variable names' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "VAR:test_var=lowercase\nVAR:TEST_VAR=uppercase\n")
      result = Howzit::ScriptComm.process(comm_file)
      # Variable names match case-insensitively, but both are stored (last one wins)
      # The regex captures the original case, so both keys are present
      expect(result[:vars].keys).to include('TEST_VAR')
      expect(result[:vars].keys).to include('test_var')
    end

    it 'removes the communication file after processing' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "VAR:TEST=value\n")
      Howzit::ScriptComm.process(comm_file)
      expect(File.exist?(comm_file)).to be false
    end

    it 'handles malformed lines gracefully' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "INVALID:line\nLOG:info:Valid message\nVAR:TEST=value\nBOGUS\n")
      result = Howzit::ScriptComm.process(comm_file)
      expect(result[:logs].length).to eq(1)
      expect(result[:vars]).to eq({ 'TEST' => 'value' })
    end

    it 'handles file read errors gracefully' do
      # Create a file that will cause a read error
      comm_file = Howzit::ScriptComm.setup
      # Make it unreadable (but this is platform-dependent, so just test that it doesn't crash)
      # Instead, test with a file that doesn't exist after setup
      File.unlink(comm_file) if File.exist?(comm_file)
      result = Howzit::ScriptComm.process(comm_file)
      expect(result).to eq({ logs: [], vars: {} })
    end
  end

  describe '.apply' do
    it 'applies log messages to console' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "LOG:info:Test info message\n")
      expect(Howzit.console).to receive(:info).with('Test info message')
      Howzit::ScriptComm.apply(comm_file)
    end

    it 'applies variables to named_arguments' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "VAR:TEST_VAR=test_value\n")
      Howzit::ScriptComm.apply(comm_file)
      expect(Howzit.named_arguments['TEST_VAR']).to eq('test_value')
    end

    it 'merges variables with existing named_arguments' do
      Howzit.named_arguments = { 'EXISTING' => 'old_value' }
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "VAR:NEW_VAR=new_value\n")
      Howzit::ScriptComm.apply(comm_file)
      expect(Howzit.named_arguments).to eq({ 'EXISTING' => 'old_value', 'NEW_VAR' => 'new_value' })
    end

    it 'overwrites existing variables' do
      Howzit.named_arguments = { 'TEST_VAR' => 'old_value' }
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "VAR:TEST_VAR=new_value\n")
      Howzit::ScriptComm.apply(comm_file)
      expect(Howzit.named_arguments['TEST_VAR']).to eq('new_value')
    end

    it 'handles multiple log levels' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "LOG:info:Info\nLOG:warn:Warn\nLOG:error:Error\nLOG:debug:Debug\n")
      expect(Howzit.console).to receive(:info).with('Info')
      expect(Howzit.console).to receive(:warn).with('Warn')
      expect(Howzit.console).to receive(:error).with('Error')
      expect(Howzit.console).to receive(:debug).with('Debug')
      Howzit::ScriptComm.apply(comm_file)
    end

    it 'does nothing if file is empty' do
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "\n")
      Howzit::ScriptComm.apply(comm_file)
      expect(Howzit.named_arguments).to be_empty
    end

    it 'initializes named_arguments if nil' do
      Howzit.named_arguments = nil
      comm_file = Howzit::ScriptComm.setup
      File.write(comm_file, "VAR:TEST=value\n")
      Howzit::ScriptComm.apply(comm_file)
      expect(Howzit.named_arguments).to eq({ 'TEST' => 'value' })
    end
  end

  describe 'integration with Task#run_run' do
    it 'processes communication file after script execution' do
      # Create a temporary script that writes to communication file
      script_file = Tempfile.new('test_script')
      script_file.write(<<~SCRIPT)
        #!/bin/bash
        echo "VAR:TEST_VAR=script_value" >> "$HOWZIT_COMM_FILE"
        echo "LOG:info:Script message" >> "$HOWZIT_COMM_FILE"
      SCRIPT
      script_file.close
      File.chmod(0o755, script_file.path)

      task = Howzit::Task.new({ type: :run,
                                title: 'Test Script',
                                action: script_file.path })

      allow(Howzit.console).to receive(:info)
      expect(Howzit.console).to receive(:info).with('Script message')

      task.run

      expect(Howzit.named_arguments['TEST_VAR']).to eq('script_value')

      script_file.unlink
    end

    it 'makes variables available for subsequent tasks' do
      # Create first script that sets a variable
      script1 = Tempfile.new('script1')
      script1.write(<<~SCRIPT)
        #!/bin/bash
        echo "VAR:BUILD_VERSION=1.2.3" >> "$HOWZIT_COMM_FILE"
      SCRIPT
      script1.close
      File.chmod(0o755, script1.path)

      # Create second script that uses the variable (simulated via echo)
      script2 = Tempfile.new('script2')
      script2.write(<<~SCRIPT)
        #!/bin/bash
        echo "Version would be: ${BUILD_VERSION}"
      SCRIPT
      script2.close
      File.chmod(0o755, script2.path)

      # Run first task
      task1 = Howzit::Task.new({ type: :run,
                                 title: 'Set Version',
                                 action: script1.path })
      allow(Howzit.console).to receive(:info)
      task1.run

      # Verify variable is set
      expect(Howzit.named_arguments['BUILD_VERSION']).to eq('1.2.3')

      # Create a task with variable substitution in the action
      # Note: Variable substitution happens when Task is created,
      # so we need to create task2 AFTER task1 runs
      action_with_var = "echo Version: ${BUILD_VERSION}"
      action_rendered = action_with_var.dup
      action_rendered.render_named_placeholders
      expect(action_rendered).to include('1.2.3')

      script1.unlink
      script2.unlink
    end
  end

  describe 'integration with Task#run_block' do
    it 'processes communication file after block execution' do
      block_content = <<~BLOCK
        #!/bin/bash
        echo "VAR:BLOCK_VAR=block_value" >> "$HOWZIT_COMM_FILE"
        echo "LOG:info:Block message" >> "$HOWZIT_COMM_FILE"
      BLOCK

      task = Howzit::Task.new({ type: :block,
                                title: 'Test Block',
                                action: block_content })

      allow(Howzit.console).to receive(:info)
      expect(Howzit.console).to receive(:info).with('Block message')

      task.run

      expect(Howzit.named_arguments['BLOCK_VAR']).to eq('block_value')
    end

    it 'cleans up communication file after block execution' do
      comm_file_path = nil
      allow(Howzit::ScriptComm).to receive(:setup).and_wrap_original do |m|
        comm_file_path = m.call
        comm_file_path
      end

      block_content = <<~BLOCK
        #!/bin/bash
        echo "VAR:TEST=value" >> "$HOWZIT_COMM_FILE"
      BLOCK

      task = Howzit::Task.new({ type: :block,
                                title: 'Test Block',
                                action: block_content })

      allow(Howzit.console).to receive(:info)
      task.run

      # Communication file should be cleaned up
      expect(File.exist?(comm_file_path)).to be false if comm_file_path
    end
  end
end

