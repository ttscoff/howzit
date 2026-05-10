# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

describe 'Topic title positional args vs gather_tasks' do
  it 'uses CLI positional snapshot so a prior topic @include […] does not shift later topic params' do
    Howzit.arguments = ['from_cli']
    Howzit.cli_topic_positional_args = ['from_cli']

    Tempfile.create(['howzit-pos', '.md']) do |f|
      f.write(<<~MD)
        defined: snap

        # Note

        ## First Topic

        @include(DoesNotNeedToExist[y])

        ## Widget Topic (only:falafel)

        ok
      MD
      f.flush

      note = Howzit::BuildNote.new(file: f.path)
      widget = note.topics.find { |t| t.title == 'Widget Topic' }
      expect(widget).not_to be_nil
      expect(widget.named_args['only']).to eq('from_cli')
    end
  end
end
