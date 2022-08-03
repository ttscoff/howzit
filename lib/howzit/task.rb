# frozen_string_literal: true

module Howzit
  class Task
    attr_reader :type, :title, :action, :parent

    def initialize(type, title, action, parent = nil)
      @type = type
      @title = title
      @action = action.render_arguments
      @parent = parent
    end

    def to_s
      @title
    end

    def to_list
      "    * #{@type}: #{@title}"
    end
  end
end
