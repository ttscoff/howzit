# frozen_string_literal: true

module Howzit
  # String Extensions
  module StringUtils
    # Just strip out color codes when requested
    def uncolor
      gsub(/\e\[[\d;]+m/, '')
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
      split(/ /).each_with_object('') do |x, ob|
        break ob unless ob.length + ' '.length + x.length <= len

        ob << (" #{x}")
      end.strip
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
      if File.exist?(File.expand_path(self))
        File.executable?(File.expand_path(self))
      else
        system "which #{self}", out: File::NULL
      end
    end

    def render_template(vars)
      content = dup
      vars.each do |k, v|
        content.gsub!(/\[%#{k}(:.*?)?\]/, v)
      end

      content.gsub(/\[%(.*?):(.*?)\]/, '\2')
    end

    def render_template!(vars)
      replace render_template(vars)
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
  end
end

class ::String
  include Howzit::StringUtils
end
