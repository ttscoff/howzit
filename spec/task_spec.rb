# frozen_string_literal: true

require 'spec_helper'

describe Howzit::Task do
  subject(:task) { Howzit::Task.new(:run, 'List Directory', 'ls') }

  describe ".new" do
    it "makes a new task instance" do
      expect(task).to be_a Howzit::Task
    end
  end
end
