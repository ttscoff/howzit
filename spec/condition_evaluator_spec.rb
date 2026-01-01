# frozen_string_literal: true

require 'spec_helper'

describe Howzit::ConditionEvaluator do
  describe '.evaluate' do
    context 'with string comparisons' do
      it 'evaluates == correctly' do
        expect(described_class.evaluate('"test" == "test"', {})).to be true
        expect(described_class.evaluate('"test" == "other"', {})).to be false
      end

      it 'evaluates =~ regex correctly' do
        expect(described_class.evaluate('"test" =~ /es/', {})).to be true
        expect(described_class.evaluate('"test" =~ /xyz/', {})).to be false
      end

      it 'evaluates *= (contains) correctly' do
        expect(described_class.evaluate('"testing" *= "est"', {})).to be true
        expect(described_class.evaluate('"testing" *= "xyz"', {})).to be false
      end

      it 'evaluates ^= (starts with) correctly' do
        expect(described_class.evaluate('"testing" ^= "test"', {})).to be true
        expect(described_class.evaluate('"testing" ^= "ing"', {})).to be false
      end

      it 'evaluates $= (ends with) correctly' do
        expect(described_class.evaluate('"testing" $= "ing"', {})).to be true
        expect(described_class.evaluate('"testing" $= "test"', {})).to be false
      end

      it 'evaluates **= (fuzzy match) correctly' do
        expect(described_class.evaluate('"fluffy" **= "ffy"', {})).to be true
        expect(described_class.evaluate('"fluffy" **= "fly"', {})).to be true
        expect(described_class.evaluate('"fluffy" **= "fuf"', {})).to be true
        expect(described_class.evaluate('"fluffy" **= "xyz"', {})).to be false
        expect(described_class.evaluate('"fluffy" **= "fxy"', {})).to be false
      end
    end

    context 'with numeric comparisons' do
      it 'evaluates == correctly' do
        expect(described_class.evaluate('5 == 5', {})).to be true
        expect(described_class.evaluate('5 == 3', {})).to be false
      end

      it 'evaluates != correctly' do
        expect(described_class.evaluate('5 != 3', {})).to be true
        expect(described_class.evaluate('5 != 5', {})).to be false
      end

      it 'evaluates > correctly' do
        expect(described_class.evaluate('5 > 3', {})).to be true
        expect(described_class.evaluate('3 > 5', {})).to be false
      end

      it 'evaluates >= correctly' do
        expect(described_class.evaluate('5 >= 5', {})).to be true
        expect(described_class.evaluate('5 >= 3', {})).to be true
        expect(described_class.evaluate('3 >= 5', {})).to be false
      end

      it 'evaluates < correctly' do
        expect(described_class.evaluate('3 < 5', {})).to be true
        expect(described_class.evaluate('5 < 3', {})).to be false
      end

      it 'evaluates <= correctly' do
        expect(described_class.evaluate('3 <= 3', {})).to be true
        expect(described_class.evaluate('3 <= 5', {})).to be true
        expect(described_class.evaluate('5 <= 3', {})).to be false
      end
    end

    context 'with negation' do
      it 'handles not prefix' do
        expect(described_class.evaluate('not "test" == "other"', {})).to be true
        expect(described_class.evaluate('not "test" == "test"', {})).to be false
      end

      it 'handles ! prefix' do
        expect(described_class.evaluate('! "test" == "other"', {})).to be true
        expect(described_class.evaluate('! "test" == "test"', {})).to be false
      end
    end

    context 'with positional arguments' do
      before do
        Howzit.arguments = %w[arg1 arg2 arg3]
      end

      after do
        Howzit.arguments = nil
      end

      it 'evaluates $1, $2, etc.' do
        expect(described_class.evaluate('$1 == "arg1"', {})).to be true
        expect(described_class.evaluate('$2 == "arg2"', {})).to be true
        expect(described_class.evaluate('$1 == "other"', {})).to be false
      end
    end

    context 'with named arguments' do
      before do
        Howzit.named_arguments = { test: 'value', other: 'thing' }
      end

      after do
        Howzit.named_arguments = nil
      end

      it 'evaluates named arguments' do
        expect(described_class.evaluate('test == "value"', {})).to be true
        expect(described_class.evaluate('other == "thing"', {})).to be true
        expect(described_class.evaluate('test == "other"', {})).to be false
      end

      it 'evaluates named arguments with ${} syntax' do
        Howzit.named_arguments = { var: 'val', env: 'production' }
        expect(described_class.evaluate('${var} == "val"', {})).to be true
        expect(described_class.evaluate('${env} == "production"', {})).to be true
        expect(described_class.evaluate('${var} == "other"', {})).to be false
      end
    end

    context 'with metadata' do
      it 'evaluates metadata keys' do
        context = { metadata: { 'key1' => 'value1', 'key2' => 'value2' } }
        expect(described_class.evaluate('key1 == "value1"', context)).to be true
        expect(described_class.evaluate('key2 == "value2"', context)).to be true
        expect(described_class.evaluate('key1 == "other"', context)).to be false
      end
    end

    context 'with environment variables' do
      it 'evaluates environment variables' do
        ENV['TEST_VAR'] = 'test_value'
        expect(described_class.evaluate('TEST_VAR == "test_value"', {})).to be true
        ENV.delete('TEST_VAR')
      end
    end

    context 'with special conditions' do
      it 'evaluates git dirty' do
        # Just test that it doesn't crash
        result = described_class.evaluate('git dirty', {})
        expect([true, false]).to include(result)
      end

      it 'evaluates git clean' do
        result = described_class.evaluate('git clean', {})
        expect([true, false]).to include(result)
      end

      it 'evaluates file exists' do
        expect(described_class.evaluate('file exists /dev/null', {})).to be true
        expect(described_class.evaluate('file exists /nonexistent/file', {})).to be false
      end

      it 'evaluates dir exists' do
        expect(described_class.evaluate('dir exists /tmp', {})).to be true
        expect(described_class.evaluate('dir exists /nonexistent/dir', {})).to be false
      end

      it 'evaluates cwd' do
        result = described_class.evaluate('cwd', {})
        expect(result).to be true
      end

      it 'evaluates working directory' do
        result = described_class.evaluate('working directory', {})
        expect(result).to be true
      end

      it 'evaluates cwd with string comparisons' do
        cwd = Dir.pwd
        expect(described_class.evaluate("cwd == \"#{cwd}\"", {})).to be true
        expect(described_class.evaluate("cwd =~ /#{Regexp.escape(File.basename(cwd))}/", {})).to be true
        expect(described_class.evaluate("cwd *= \"#{File.basename(cwd)}\"", {})).to be true
        expect(described_class.evaluate("cwd ^= \"#{cwd[0..10]}\"", {})).to be true
        expect(described_class.evaluate("cwd $= \"#{cwd[-10..-1]}\"", {})).to be true
      end
    end

    context 'with file contents conditions' do
      let(:test_file) { 'test_version.txt' }

      before do
        File.write(test_file, '0.1.2')
      end

      after do
        File.delete(test_file) if File.exist?(test_file)
      end

      it 'evaluates file contents ^= (starts with) correctly' do
        expect(described_class.evaluate("file contents #{test_file} ^= 0.", {})).to be true
        expect(described_class.evaluate("file contents #{test_file} ^= 1.", {})).to be false
      end

      it 'evaluates file contents *= (contains) correctly' do
        expect(described_class.evaluate("file contents #{test_file} *= 1.2", {})).to be true
        expect(described_class.evaluate("file contents #{test_file} *= 2.3", {})).to be false
      end

      it 'evaluates file contents $= (ends with) correctly' do
        expect(described_class.evaluate("file contents #{test_file} $= .2", {})).to be true
        expect(described_class.evaluate("file contents #{test_file} $= .3", {})).to be false
      end

      it 'evaluates file contents == correctly' do
        expect(described_class.evaluate("file contents #{test_file} == 0.1.2", {})).to be true
        expect(described_class.evaluate("file contents #{test_file} == 1.0.0", {})).to be false
      end

      it 'evaluates file contents != correctly' do
        expect(described_class.evaluate("file contents #{test_file} != 1.0.0", {})).to be true
        expect(described_class.evaluate("file contents #{test_file} != 0.1.2", {})).to be false
      end

      it 'evaluates file contents **= (fuzzy match) correctly' do
        expect(described_class.evaluate("file contents #{test_file} **= 012", {})).to be true
        expect(described_class.evaluate("file contents #{test_file} **= 021", {})).to be false
      end

      it 'evaluates file contents =~ (regex) correctly' do
        expect(described_class.evaluate("file contents #{test_file} =~ /0\\.\\d+\\.\\d+/", {})).to be true
        expect(described_class.evaluate("file contents #{test_file} =~ /1\\.\\d+\\.\\d+/", {})).to be false
      end

      it 'returns false for non-existent file' do
        expect(described_class.evaluate('file contents nonexistent.txt ^= 0.', {})).to be false
      end

      it 'handles file path as variable' do
        context = { metadata: { 'version_file' => test_file } }
        expect(described_class.evaluate('file contents version_file ^= 0.', context)).to be true
      end
    end

    context 'with simple existence checks' do
      before do
        Howzit.named_arguments = { defined_var: 'value' }
      end

      after do
        Howzit.named_arguments = nil
      end

      it 'returns true for defined variables' do
        expect(described_class.evaluate('defined_var', {})).to be true
      end

      it 'returns false for undefined variables' do
        expect(described_class.evaluate('undefined_var', {})).to be false
      end
    end
  end
end

