require 'spec_helper'

describe Makenew::RubyGem do
  subject(:ruby_gem) { Makenew::RubyGem.new }

  describe ".new" do
    it "makes a new instance" do
      expect(ruby_gem).to be_a Makenew::RubyGem
    end
  end
end
