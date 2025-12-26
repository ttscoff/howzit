# frozen_string_literal: true

require 'spec_helper'

describe 'StringUtils' do
  describe '#render_named_placeholders' do
    before do
      Howzit.named_arguments = {}
    end

    it 'preserves ${VAR} syntax when variable is not defined' do
      str = 'echo ${MY_VAR}'.dup
      str.render_named_placeholders
      expect(str).to eq('echo ${MY_VAR}')
    end

    it 'preserves ${VAR} syntax for multiple undefined variables' do
      str = 'echo ${VAR1} and ${VAR2}'.dup
      str.render_named_placeholders
      expect(str).to eq('echo ${VAR1} and ${VAR2}')
    end

    it 'replaces ${VAR} with value when variable is defined' do
      Howzit.named_arguments = { 'MY_VAR' => 'hello' }
      str = 'echo ${MY_VAR}'.dup
      str.render_named_placeholders
      expect(str).to eq('echo hello')
    end

    it 'uses default value when variable is not defined but default is provided' do
      str = 'echo ${MY_VAR:default_value}'.dup
      str.render_named_placeholders
      expect(str).to eq('echo default_value')
    end

    it 'replaces variable when defined even if default is provided' do
      Howzit.named_arguments = { 'MY_VAR' => 'actual_value' }
      str = 'echo ${MY_VAR:default_value}'.dup
      str.render_named_placeholders
      expect(str).to eq('echo actual_value')
    end

    it 'preserves ${VAR} in bash script blocks' do
      script = <<~SCRIPT
        #!/bin/bash
        echo "The value is ${ENV_VAR}"
        echo "Another ${OTHER_VAR}"
      SCRIPT
      str = script.dup
      str.render_named_placeholders
      expect(str).to eq(script)
    end

    it 'handles mixed defined and undefined variables' do
      Howzit.named_arguments = { 'DEFINED_VAR' => 'value1' }
      str = 'echo ${DEFINED_VAR} and ${UNDEFINED_VAR}'.dup
      str.render_named_placeholders
      expect(str).to eq('echo value1 and ${UNDEFINED_VAR}')
    end

    it 'handles nil named_arguments gracefully' do
      Howzit.named_arguments = nil
      str = 'echo ${MY_VAR}'.dup
      expect { str.render_named_placeholders }.not_to raise_error
      expect(str).to eq('echo ${MY_VAR}')
    end
  end

  describe '#render_arguments' do
    before do
      Howzit.named_arguments = {}
      Howzit.arguments = nil
    end

    it 'preserves ${VAR} syntax through render_arguments' do
      str = 'echo ${BASH_VAR}'.dup
      result = str.render_arguments
      expect(result).to eq('echo ${BASH_VAR}')
    end
  end
end

