# frozen_string_literal: true

module Howzit
  # String Extensions
  module StringUtils
    ## Compare strings and return a distance
    ##
    ## @param      other  [String] The string to compare
    ## @param      term   [String] The search term
    ##
    ## @return [Float] distance
    def comp_distance(term)
      chars = term.split(//)
      contains_count(chars) + distance(chars)
    end

    ##
    ## Number of matching characters the string contains
    ##
    ## @param      chars [String|Array]  The characters
    ##
    def contains_count(chars)
      chars = chars.split(//) if chars.is_a?(String)
      count = 0
      chars.each { |char| count += 1 if self =~ /#{char}/i }
      count
    end

    ##
    ## Determine if characters are in order
    ##
    ## @param      chars  [String|Array] The characters
    ##
    ## @return [Boolean] characters are in order
    ##
    def in_order(chars)
      chars = chars.split(//) if chars.is_a?(String)
      position = 0
      in_order = 0
      chars.each do |char|
        new_pos = self[position..] =~ /#{char}/i
        if new_pos
          position += new_pos
          in_order += 1
        end
      end
      in_order
    end

    ##
    ## Determine if a series of characters are all within a given distance of
    ## each other in the String
    ##
    ## @param      chars     [String|Array] The characters
    ## @param      distance  [Number] The distance
    ##
    ## @return     [Boolean] true if within distance
    ##
    def in_distance?(chars, distance)
      chars = chars.split(//) if chars.is_a?(String)
      rx = Regexp.new(chars.join(".{,#{distance}}"), 'i')
      self =~ rx ? true : false
    end

    ##
    ## Determine the minimum distance between characters that they all still
    ## fall within
    ##
    ## @param      chars  [Array] The characters
    ##
    ## @return     [Number] distance
    ##
    def distance(chars)
      distance = 0
      max = length - chars.length
      return max unless in_order(chars) == chars.length

      while distance < max
        return distance if in_distance?(chars, distance)

        distance += 1
      end
      distance
    end

    ##
    ## Test if the filename matches the conditions to be a build note
    ##
    ## @return     [Boolean] true if filename passes test
    ##
    def build_note?
      return false if downcase !~ /^(howzit[^.]*|build[^.]+)/

      # Avoid recursion: only check ignore patterns if config is fully initialized
      # and we're not in the middle of loading ignore patterns or initializing
      begin
        # Check if config exists without triggering initialization
        return true unless Howzit.instance_variable_defined?(:@config)

        config = Howzit.instance_variable_get(:@config)
        return true unless config

        # Check if config is initializing or loading ignore patterns to prevent recursion
        return true if config.instance_variable_defined?(:@initializing) && config.instance_variable_get(:@initializing)
        if config.instance_variable_defined?(:@loading_ignore_patterns) && config.instance_variable_get(:@loading_ignore_patterns)
          return true
        end

        return false if config.respond_to?(:should_ignore) && config.should_ignore(self)
      rescue StandardError
        # If config access fails for any reason, skip the ignore check
        # This prevents recursion and handles initialization edge cases
      end

      true
    end

    ##
    ## Get the title of the build note (top level header)
    ##
    ## @param      truncate  [Integer] Truncate to width
    ##
    def note_title(file, truncate = 0)
      title = match(/(?:^(\S.*?)(?=\n==)|^# ?(.*?)$)/)
      title = if title
                title[1].nil? ? title[2] : title[1]
              else
                file.sub(/(\.\w+)?$/, '')
              end

      title && truncate.positive? ? title.trunc(truncate) : title
    end

    ##
    ## Replace slash escaped characters in a string with a
    ## zero-width space that will prevent a shell from
    ## interpreting them when output to console
    ##
    ## @return     [String] new string
    ##
    def preserve_escapes
      gsub(/\\([a-z])/, '\​\1')
    end

    # Convert a string to a valid YAML value
    #
    # @param      orig_value  The original value from which
    #                         type will be determined
    #
    # @return     coerced value
    #
    def to_config_value(orig_value = nil)
      if orig_value
        case orig_value.class.to_s
        when /Integer/
          to_i
        when /(True|False)Class/
          self =~ /^(t(rue)?|y(es)?|1)$/i ? true : false
        else
          self
        end
      else
        case self
        when /^[0-9]+$/
          to_i
        when /^(t(rue)?|y(es)?)$/i
          true
        when /^(f(alse)?|n(o)?)$/i
          false
        else
          self
        end
      end
    end

    ##
    ## Shortcut for calling Color.template
    ##
    ## @return     [String] colorized string
    ##
    def c
      Color.template(self)
    end

    ##
    ## Convert a string to a regex object based on matching settings
    ##
    ## @return     [Regexp] Receive regex representation of the object.
    ##
    def to_rx
      case Howzit.options[:matching]
      when 'exact'
        /^#{self}$/i
      when 'beginswith'
        /^#{self}/i
      when 'fuzzy'
        # For fuzzy matching, use token-based matching where each word gets fuzzy character matching
        # This allows "lst tst" to match "List Available Tests" by applying fuzzy matching to each token
        words = split(/\s+/).reject(&:empty?)
        if words.length > 1
          # Multiple words: apply character-by-character fuzzy matching to each word token
          # Then allow flexible matching between words
          pattern = words.map do |w|
            # Apply fuzzy matching to each word (character-by-character with up to 3 chars between)
            w.split(//).map { |c| Regexp.escape(c) }.join('.{0,3}?')
          end.join('.*')
          /#{pattern}/i
        else
          # Single word: character-by-character fuzzy matching for flexibility
          /#{split(//).join('.{0,3}?')}/i
        end
      when 'token'
        # Token-based matching: match words in order with any text between them
        # "list tests" matches "list available tests", "list of tests", etc.
        words = split(/\s+/).reject(&:empty?)
        if words.length > 1
          pattern = words.map { |w| Regexp.escape(w) }.join('.*')
          /#{pattern}/i
        else
          /#{Regexp.escape(self)}/i
        end
      else
        # Default 'partial' mode: token-based matching for multi-word searches
        # This allows "list tests" to match "list available tests"
        words = split(/\s+/).reject(&:empty?)
        if words.length > 1
          # Token-based: match words in order with any text between
          pattern = words.map { |w| Regexp.escape(w) }.join('.*')
          /#{pattern}/i
        else
          # Single word: simple substring match
          /#{Regexp.escape(self)}/i
        end
      end
    end

    # Just strip out color codes when requested
    def uncolor
      # force UTF-8 and remove invalid characters, then remove color codes
      # and iTerm markers
      gsub(Howzit::Color::COLORED_REGEXP, '').gsub(/\e\]1337;SetMark/, '')
    end

    # Wrap text at a specified width.
    #
    # Adapted from https://github.com/pazdera/word_wrap/,
    # copyright (c) 2014, 2015  Radek Pazdera Distributed
    # under the MIT License
    #
    # @param      width  [Integer] The width at which to
    #                    wrap lines
    #
    # @return     [String] wrapped string
    #
    def wrap(width)
      width ||= 80
      output = []
      indent = ''

      text = gsub(/\t/, '  ')

      text.lines do |line|
        line.chomp! "\n"
        if line.length > width
          indent = if line.uncolor =~ /^(\s*(?:[+\-*]|\d+\.) )/
                     ' ' * Regexp.last_match[1].length
                   else
                     ''
                   end
          new_lines = line.split_line(width)

          while new_lines.length > 1 && new_lines[1].length + indent.length > width
            output.push new_lines[0]

            new_lines = new_lines[1].split_line(width, indent)
          end
          output += [new_lines[0], indent + new_lines[1]]
        else
          output.push line
        end
      end
      output.map!(&:rstrip)
      output.join("\n")
    end

    ##
    ## Wrap string in place (destructive)
    ##
    ## @param      width  [Integer] The width at which to wrap
    ##
    def wrap!(width)
      replace(wrap(width))
    end

    # Truncate string to nearest word
    #
    # @param      len   [Integer] max length of string
    #
    def trunc(len)
      split(/ /).each_with_object([]) do |x, ob|
        break ob unless ob.join(' ').length + ' '.length + x.length <= len

        ob.push(x)
      end.join(' ').strip
    end

    ##
    ## Truncate string in place (destructive)
    ##
    ## @param      len   [Integer] The length to truncate at
    ##
    def trunc!(len)
      replace trunc(len)
    end

    ##
    ## Splits a line at nearest word break
    ##
    ## @param      width   [Integer] The width of the first segment
    ## @param      indent  [String] The indent string
    ##
    def split_line(width, indent = '')
      line = dup
      at = line.index(/\s/)
      last_at = at

      while !at.nil? && at < width
        last_at = at
        at = line.index(/\s/, last_at + 1)
      end

      if last_at.nil?
        [indent + line[0, width], line[width, line.length]]
      else
        [indent + line[0, last_at], line[last_at + 1, line.length]]
      end
    end

    ##
    ## Test if an executable is available on the system
    ##
    ## @return     [Boolean] executable is available
    ##
    def available?
      Util.valid_command?(self)
    end

    ##
    ## Render [%variable] placeholders in a templated string
    ##
    ## @param      vars  [Hash] Key/value pairs of variable
    ##                   values
    ##
    ## @return     [String] Rendered string
    ##
    def render_template(vars)
      vars.each do |k, v|
        gsub!(/\[%#{k}(:.*?)?\]/, v)
      end

      # Replace empty variables with default
      gsub!(/\[%([^\]]+?):(.*?)\]/, '\2')

      # Remove remaining empty variables
      gsub(/\[%.*?\]/, '')
    end

    ##
    ## Render [%variable] placeholders in place
    ##
    ## @param      vars  [Hash] Key/value pairs of variable values
    ##
    def render_template!(vars)
      replace render_template(vars)
    end

    ##
    ## Render $X placeholders based on positional arguments
    ##
    ## @return     [String] rendered string
    ##
    def render_arguments
      str = dup
      str.render_named_placeholders
      str.render_numeric_placeholders
      Howzit.arguments.nil? ? str : str.gsub(/\$[@*]/, Shellwords.join(Howzit.arguments))
    end

    def render_named_placeholders
      gsub!(/\$\{(?<name>[A-Z0-9_]+(?::.*?)?)\}/i) do
        m = Regexp.last_match
        arg, default = m['name'].split(/:/).map(&:strip)
        if Howzit.named_arguments&.key?(arg) && !Howzit.named_arguments[arg].nil?
          Howzit.named_arguments[arg]
        elsif default
          default
        else
          # Preserve the original ${VAR} syntax if variable is not defined and no default provided
          m[0]
        end
      end
    end

    def render_numeric_placeholders
      gsub!(/\$\{?(\d+)\}?/) do
        arg, default = Regexp.last_match(1).split(/:/)
        idx = arg.to_i - 1
        Howzit.arguments.length > idx ? Howzit.arguments[idx] : default || Regexp.last_match(0)
      end
    end

    ##
    ## Split the content at the first top-level header and
    ## assume everything before it is metadata. Passes to
    ## #metadata for processing
    ##
    ## @return     [Hash] key/value pairs
    ##
    def extract_metadata
      if File.exist?(self)
        leader = Util.read_file(self).split(/^#/)[0].strip
        leader.length.positive? ? leader.metadata : {}
      else
        {}
      end
    end

    ##
    ## Examine text for metadata and return key/value pairs
    ##
    ## Supports:
    ## - YAML front matter (starting with --- and ending with --- or ...)
    ## - MultiMarkdown-style key: value lines (up to first blank line)
    ##
    ## @return     [Hash] The metadata as key/value pairs
    ##
    def metadata
      data = {}
      lines = to_s.lines
      first_idx = lines.index { |l| l !~ /^\s*$/ }
      return {} unless first_idx

      first = lines[first_idx]

      if first =~ /^---\s*$/
        # YAML front matter: between first --- and closing --- or ...
        closing_rel = lines[(first_idx + 1)..].index { |l| l =~ /^(---|\.\.\.)\s*$/ }
        closing_idx = closing_rel ? first_idx + 1 + closing_rel : lines.length
        yaml_body = lines[(first_idx + 1)...closing_idx].join
        raw = yaml_body.strip.empty? ? {} : YAML.load(yaml_body) || {}
        if raw.is_a?(Hash)
          raw.each do |k, v|
            data[k.to_s.downcase] = v
          end
        end
      else
        # MultiMarkdown-style: key: value lines up to first blank line
        header_lines = []
        lines[first_idx..].each do |l|
          break if l =~ /^\s*$/

          header_lines << l
        end
        header = header_lines.join
        header.scan(/(?mi)^(\S[\s\S]+?): ([\s\S]*?)(?=\n\S[\s\S]*?:|\Z)/).each do |m|
          data[m[0].strip.downcase] = m[1]
        end
      end

      out = normalize_metadata(data)
      Howzit.named_arguments ||= {}
      Howzit.named_arguments = out.merge(Howzit.named_arguments)
      out
    end

    ##
    ## Autocorrect some keys
    ##
    ## @param      meta  [Hash] The metadata
    ##
    ## @return     [Hash] corrected metadata
    ##
    def normalize_metadata(meta)
      data = {}
      meta.each do |k, v|
        case k
        when /^te?m?pl(ate)?s?$/
          data['template'] = v
        when /^req\w*$/
          data['required'] = v
        else
          data[k] = v
        end
      end
      data
    end

    ##
    ## Test if iTerm markers should be output. Requires that
    ## the $TERM_PROGRAM be iTerm and howzit is not running
    ## directives or paginating output
    ##
    ## @return     [Boolean] should mark?
    ##
    def should_mark_iterm?
      ENV['TERM_PROGRAM'] =~ /^iTerm/ && !Howzit.options[:run] && !Howzit.options[:paginate]
    end

    ##
    ## Output an iTerm marker
    ##
    ## @return     [String] ANSI escape sequence for iTerm
    ##             marker
    ##
    def iterm_marker
      "\e]1337;SetMark\a" if should_mark_iterm?
    end

    # Make a fancy title line for the topic
    #
    # @param      opts  [Hash] options
    #
    # @return     [String] formatted string
    #
    def format_header(opts = {})
      title = dup
      options = {
        hr: "\u{254C}",
        color: '{bg}',
        border: '{x}',
        mark: should_mark_iterm?
      }

      options.merge!(opts)

      case Howzit.options[:header_format]
      when :block
        Color.template("\n\n#{options[:color]}\u{258C}#{title}#{should_mark_iterm? && options[:mark] ? iterm_marker : ''}{x}")
      else
        cols = TTY::Screen.columns

        cols = Howzit.options[:wrap] if Howzit.options[:wrap].positive? && cols > Howzit.options[:wrap]
        title = Color.template("#{options[:border]}#{options[:hr] * 2}( #{options[:color]}#{title}#{options[:border]} )")

        # Calculate remaining width for horizontal rule, ensuring it is never negative
        remaining = cols - title.uncolor.length
        if should_mark_iterm?
          # Reserve some space for the iTerm mark escape sequence in the visual layout
          remaining -= 15
        end
        remaining = 0 if remaining.negative?

        hr_tail = options[:hr] * remaining
        tail = if should_mark_iterm?
                 "#{hr_tail}#{options[:mark] ? iterm_marker : ''}"
               else
                 hr_tail
               end

        Color.template("\n\n#{title}#{tail}{x}\n\n")
      end
    end
  end
end

class ::String
  include Howzit::StringUtils
end
