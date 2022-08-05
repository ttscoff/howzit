# frozen_string_literal: true

module Howzit
  # Task object
  class Task
    attr_reader :type, :title, :action, :parent, :optional, :default

    ##
    ## Initialize a Task object
    ##
    def initialize(params, optional: false, default: true)
      @type = params[:type]
      @title = params[:title]
      @action = params[:action].render_arguments
      @parent = params[:parent] || nil
      @optional = optional
      @default = default
    end

    ##
    ## Inspect
    ##
    ## @return     [String] description
    ##
    def inspect
      %(<#Howzit::Task @type=:#{@type} @title="#{@title}" @block?=#{@action.split(/\n/).count > 1}>)
    end

    ##
    ## Output string representation
    ##
    ## @return     [String] string representation of the object.
    ##
    def to_s
      @title
    end

    ##
    ## Output terminal-formatted list item
    ##
    ## @return     [String] List representation of the object.
    ##
    def to_list
      "    * #{@type}: #{@title.preserve_escapes}"
    end
  end
end
