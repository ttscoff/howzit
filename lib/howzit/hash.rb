# frozen_string_literal: true

# Hash helpers
class ::Hash
  ##
  ## Freeze all values in a hash
  ##
  ## @return     Hash with all values frozen
  ##
  def deep_freeze
    chilled = {}
    each do |k, v|
      chilled[k] = v.is_a?(Hash) ? v.deep_freeze : v.freeze
    end

    chilled.freeze
  end

  def deep_freeze!
    replace deep_thaw.deep_freeze
  end

  def deep_thaw
    chilled = {}
    each do |k, v|
      chilled[k] = v.is_a?(Hash) ? v.deep_thaw : v.dup
    end

    chilled.dup
  end

  def deep_thaw!
    replace deep_thaw
  end
end
