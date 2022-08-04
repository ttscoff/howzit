# frozen_string_literal: true

module Howzit
  class Task
    attr_reader :type, :title, :action, :parent, :optional, :default

    def initialize(type, title, action, parent = nil, optional: false, default: true)
      @type = type
      @title = title
      @action = action.render_arguments
      @parent = parent
      @optional = optional
      @default = default
    end

    def to_s
      @title
    end

    def to_list
      "    * #{@type}: #{@title.gsub(/\\n/, '\​n')}"
    end
  end
end
