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

  # Turn all keys into string
  #
  # Return a copy of the hash where all its keys are strings
  def stringify_keys
    each_with_object({}) { |(k, v), hsh| hsh[k.to_s] = v.is_a?(Hash) ? v.stringify_keys : v }
  end

  def stringify_keys!
  	replace stringify_keys
  end

  # Turn all keys into symbols
  def symbolize_keys
    each_with_object({}) { |(k, v), hsh| hsh[k.to_sym] = v.is_a?(Hash) ? v.symbolize_keys : v }
  end

  def symbolize_keys!
  	replace symbolize_keys
  end
end
