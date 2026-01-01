# frozen_string_literal: true

require 'spec_helper'

describe Howzit::ConditionalContent do
  describe '.process' do
    context 'with simple @if blocks' do
      it 'includes content when condition is true' do
        content = <<~CONTENT
          @if "test" == "test"
          This should be included
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).to include('This should be included')
        expect(result).not_to include('@if')
        expect(result).not_to include('@end')
      end

      it 'excludes content when condition is false' do
        content = <<~CONTENT
          @if "test" == "other"
          This should NOT be included
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).not_to include('This should NOT be included')
      end
    end

    context 'with @unless blocks' do
      it 'includes content when condition is false' do
        content = <<~CONTENT
          @unless "test" == "other"
          This should be included
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).to include('This should be included')
      end

      it 'excludes content when condition is true' do
        content = <<~CONTENT
          @unless "test" == "test"
          This should NOT be included
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).not_to include('This should NOT be included')
      end
    end

    context 'with nested blocks' do
      it 'handles nested @if blocks correctly' do
        content = <<~CONTENT
          @if "outer" == "outer"
          Outer content
          @if "inner" == "inner"
          Inner content
          @end
          More outer content
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).to include('Outer content')
        expect(result).to include('Inner content')
        expect(result).to include('More outer content')
      end

      it 'excludes nested content when outer condition is false' do
        content = <<~CONTENT
          @if "outer" == "other"
          Outer content
          @if "inner" == "inner"
          Inner content
          @end
          More outer content
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).not_to include('Outer content')
        expect(result).not_to include('Inner content')
        expect(result).not_to include('More outer content')
      end

      it 'excludes nested content when inner condition is false' do
        content = <<~CONTENT
          @if "outer" == "outer"
          Outer content
          @if "inner" == "other"
          Inner content
          @end
          More outer content
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).to include('Outer content')
        expect(result).not_to include('Inner content')
        expect(result).to include('More outer content')
      end
    end

    context 'with @run directives inside blocks' do
      it 'includes @run when condition is true' do
        content = <<~CONTENT
          @if 1 == 1
          @run(echo "test")
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).to include('@run(echo "test")')
      end

      it 'excludes @run when condition is false' do
        content = <<~CONTENT
          @if 1 == 2
          @run(echo "test")
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).not_to include('@run(echo "test")')
      end
    end

    context 'with code blocks inside conditional blocks' do
      it 'includes code blocks when condition is true' do
        content = <<~CONTENT
          @if "test" == "test"
          ```run
          echo "hello"
          ```
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).to include('```run')
        expect(result).to include('echo "hello"')
      end

      it 'excludes code blocks when condition is false' do
        content = <<~CONTENT
          @if "test" == "other"
          ```run
          echo "hello"
          ```
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).not_to include('```run')
        expect(result).not_to include('echo "hello"')
      end
    end

    context 'with metadata in conditions' do
      it 'uses metadata from context' do
        content = <<~CONTENT
          @if env == "production"
          Production content
          @end
        CONTENT

        context = { metadata: { 'env' => 'production' } }
        result = described_class.process(content, context)
        expect(result).to include('Production content')
      end
    end

    context 'with multiple sequential blocks' do
      it 'handles multiple independent blocks' do
        content = <<~CONTENT
          @if 1 == 1
          First block
          @end
          @if 2 == 2
          Second block
          @end
        CONTENT

        result = described_class.process(content, {})
        expect(result).to include('First block')
        expect(result).to include('Second block')
      end
    end
  end
end

