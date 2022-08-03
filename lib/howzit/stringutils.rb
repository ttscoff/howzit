# frozen_string_literal: true

module Howzit
  # String Extensions
  module StringUtils
    # Convert a string to a valid YAML value
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

    def to_rx
      case Howzit.options[:matching]
      when 'exact'
        /^#{self}$/i
      when 'beginswith'
        /^#{self}/i
      when 'fuzzy'
        /#{split(//).join('.*?')}/i
      else
        /#{self}/i
      end
    end

    # Just strip out color codes when requested
    def uncolor
      gsub(/\e\[[\d;]+m/, '').gsub(/\e\]1337;SetMark/,'')
    end

    # Adapted from https://github.com/pazdera/word_wrap/,
    # copyright (c) 2014, 2015  Radek Pazdera
    # Distributed under the MIT License
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

    def wrap!(width)
      replace(wrap(width))
    end

    # Truncate string to nearest word
    # @param len <number> max length of string
    def trunc(len)
      split(/ /).each_with_object([]) do |x, ob|
        break ob unless ob.join(' ').length + ' '.length + x.length <= len

        ob.push(x)
      end.join(' ').strip
    end

    def trunc!(len)
      replace trunc(len)
    end

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

    def available?
      Util.valid_command?(self)
    end

    def render_template(vars)
      vars.each do |k, v|
        gsub!(/\[%#{k}(:.*?)?\]/, v)
      end

      gsub(/\[%(.*?):(.*?)\]/, '\2')
    end

    def render_template!(vars)
      replace render_template(vars)
    end

    def render_arguments
      return self if Howzit.arguments.nil? || Howzit.arguments.empty?

      gsub!(/\$(\d+)/) do |m|
        idx = m[1].to_i - 1
        Howzit.arguments.length > idx ? Howzit.arguments[idx] : m
      end
      gsub(/\$[@*]/, Shellwords.join(Howzit.arguments))
    end

    def extract_metadata
      if File.exist?(self)
        leader = IO.read(self).split(/^#/)[0].strip
        leader.length > 0 ? leader.get_metadata : {}
      else
        {}
      end
    end

    def get_metadata
      data = {}
      scan(/(?mi)^(\S[\s\S]+?): ([\s\S]*?)(?=\n\S[\s\S]*?:|\Z)/).each do |m|
        data[m[0].strip.downcase] = m[1]
      end
      normalize_metadata(data)
    end

    def normalize_metadata(meta)
      data = {}
      meta.each do |k, v|
        case k
        when /^templ\w+$/
          data['template'] = v
        when /^req\w+$/
          data['required'] = v
        else
          data[k] = v
        end
      end
      data
    end

    def should_mark_iterm?
      ENV['TERM_PROGRAM'] =~ /^iTerm/ && !Howzit.options[:run] && !Howzit.options[:paginate]
    end

    def iterm_marker
      "\e]1337;SetMark\a" if should_mark_iterm?
    end

    # Make a fancy title line for the topic
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
        Color.template("#{options[:color]}\u{258C}#{title}#{should_mark_iterm? && options[:mark] ? iterm_marker : ''}{x}")
      else
        cols = TTY::Screen.columns

        cols = Howzit.options[:wrap] if (Howzit.options[:wrap]).positive? && cols > Howzit.options[:wrap]
        title = Color.template("#{options[:border]}#{options[:hr] * 2}( #{options[:color]}#{title}#{options[:border]} )")

        tail = if should_mark_iterm?
                 "#{options[:hr] * (cols - title.uncolor.length - 15)}#{options[:mark] ? iterm_marker : ''}"
               else
                 options[:hr] * (cols - title.uncolor.length)
               end
        Color.template("#{title}#{tail}{x}")
      end
    end
  end
end

class ::String
  include Howzit::StringUtils
end
