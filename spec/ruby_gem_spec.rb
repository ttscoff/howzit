# frozen_string_literal: true

require 'spec_helper'

describe Howzit::BuildNote do
  subject(:buildnote) { Howzit.buildnote }

  describe ".new" do
    it "makes a new instance" do
      expect(buildnote).to be_a Howzit::BuildNote
    end
  end
end
