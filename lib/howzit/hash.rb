# frozen_string_literal: true

# Hash helpers
class ::Hash
  ##
  ## Freeze all values in a hash
  ##
  ## @return     [Hash] Hash with all values frozen
  ##
  def deep_freeze
    chilled = {}
    each do |k, v|
      chilled[k] = v.is_a?(Hash) ? v.deep_freeze : v.freeze
    end

    chilled.freeze
  end

  ##
  ## Deep freeze a hash in place (destructive)
  ##
  def deep_freeze!
    replace deep_thaw.deep_freeze
  end

  ##
  ## Unfreeze nested hash values
  ##
  ## @return     [Hash] Hash with all values unfrozen
  ##
  def deep_thaw
    chilled = {}
    each do |k, v|
      chilled[k] = v.is_a?(Hash) ? v.deep_thaw : v.dup
    end

    chilled.dup
  end

  ##
  ## Unfreeze nested hash values in place (destructive)
  ##
  def deep_thaw!
    replace deep_thaw
  end

  # Turn all keys into string
  #
  # @return     [Hash] hash with all keys as strings
  #
  def stringify_keys
    each_with_object({}) { |(k, v), hsh| hsh[k.to_s] = v.is_a?(Hash) ? v.stringify_keys : v }
  end

  ##
  ## Turn all keys into strings in place (destructive)
  ##
  def stringify_keys!
    replace stringify_keys
  end

  # Turn all keys into symbols
  #
  # @return     [Hash] hash with all keys as symbols
  #
  def symbolize_keys
    each_with_object({}) { |(k, v), hsh| hsh[k.to_sym] = v.is_a?(Hash) ? v.symbolize_keys : v }
  end

  ##
  ## Turn all keys into symbols in place (destructive)
  ##
  def symbolize_keys!
    replace symbolize_keys
  end
end
