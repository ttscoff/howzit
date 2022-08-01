require 'spec_helper'

describe Howzit::BuildNotes do
  subject(:ruby_gem) { Howzit::BuildNotes.new }

  describe ".new" do
    it "makes a new instance" do
      expect(ruby_gem).to be_a Howzit::BuildNotes
    end
  end
end
