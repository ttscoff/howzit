# frozen_string_literal: true

module Howzit
  # Topic Class
  class Topic
    attr_writer :parent

    attr_accessor :content

    attr_reader :title, :tasks, :prereqs, :postreqs

    def initialize(title, content)
      @title = title
      @content = content
      @parent = nil
      @nest_level = 0
      @tasks = gather_tasks
    end

    def grep(term)
      @title =~ /#{term}/i || @content =~ /#{term}/i
    end

    # Handle run command, execute directives
    def run(nested: false)
      output = []
      tasks = 0
      if @tasks.count.positive?
        unless @prereqs.empty?
          puts @prereqs.join("\n\n")
          res = Prompt.yn('This topic has prerequisites, have they been met?', default: true)
          Process.exit 1 unless res

        end

        @tasks.each do |task|
          if task.optional
            q = %({bg}#{task.type.to_s.capitalize} {xw}"{bw}#{task.title}{xw}"{x}).c
            res = Prompt.yn(q, default: task.default)
            next unless res

          end

          if task.type == :block
            warn "{bg}Running block {bw}#{title}{x}".c if Howzit.options[:log_level] < 2
            block = task.action
            script = Tempfile.new('howzit_script')
            begin
              script.write(block)
              script.close
              File.chmod(0777, script.path)
              system(%(/bin/sh -c "#{script.path}"))
              tasks += 1
            ensure
              script.close
              script.unlink
            end
          else
            title = Howzit.options[:show_all_code] ? task.action : task.title
            case task.type
            when :include
              matches = Howzit.buildnote.find_topic(task.action)
              raise "Topic not found: #{task.action}" if matches.empty?

              $stderr.puts "{by}Running tasks from {bw}#{matches[0].title}{x}".c if Howzit.options[:log_level] < 2
              output.push(matches[0].run(nested: true))
              $stderr.puts "{by}End include: #{matches[0].tasks.count} tasks".c if Howzit.options[:log_level] < 2
              tasks += matches[0].tasks.count
            when :run
              $stderr.puts "{bg}Running {bw}#{title}{x}".c if Howzit.options[:log_level] < 2
              system(task.action)
              tasks += 1
            when :copy
              $stderr.puts "{bg}Copied {bw}#{title}{bg} to clipboard{x}".c if Howzit.options[:log_level] < 2
              os_copy(task.action)
              tasks += 1
            when :open
              os_open(task.action)
              tasks += 1
            end
          end
        end
      else
        warn "{r}--run: No {br}@directive{xr} found in {bw}#{@title}{x}".c
      end
      output.push("{bm}Ran #{tasks} #{tasks == 1 ? 'task' : 'tasks'}{x}".c) if Howzit.options[:log_level] < 2 && !nested

      puts postreqs.join("\n\n") unless postreqs.empty?

      output
    end

    def os_copy(string)
      os = RbConfig::CONFIG['target_os']
      out = "{bg}Copying {bw}#{string}".c
      case os
      when /darwin.*/i
        warn "#{out} (macOS){x}".c if Howzit.options[:log_level] < 2
        `echo #{Shellwords.escape(string)}'\\c'|pbcopy`
      when /mingw|mswin/i
        warn "#{out} (Windows){x}".c if Howzit.options[:log_level] < 2
        `echo #{Shellwords.escape(string)} | clip`
      else
        if 'xsel'.available?
          warn "#{out} (Linux, xsel){x}".c if Howzit.options[:log_level] < 2
          `echo #{Shellwords.escape(string)}'\\c'|xsel -i`
        elsif 'xclip'.available?
          warn "#{out} (Linux, xclip){x}".c if Howzit.options[:log_level] < 2
          `echo #{Shellwords.escape(string)}'\\c'|xclip -i`
        else
          warn out if Howzit.options[:log_level] < 2
          warn 'Unable to determine executable for clipboard.'
        end
      end
    end

    def os_open(command)
      os = RbConfig::CONFIG['target_os']
      out = "{bg}Opening {bw}#{command}".c
      case os
      when /darwin.*/i
        warn "#{out} (macOS){x}".c if Howzit.options[:log_level] < 2
        `open #{Shellwords.escape(command)}`
      when /mingw|mswin/i
        warn "#{out} (Windows){x}".c if Howzit.options[:log_level] < 2
        `start #{Shellwords.escape(command)}`
      else
        if 'xdg-open'.available?
          warn "#{out} (Linux){x}".c if Howzit.options[:log_level] < 2
          `xdg-open #{Shellwords.escape(command)}`
        else
          warn out if Howzit.options[:log_level] < 2
          warn 'Unable to determine executable for `open`.'
        end
      end
    end

    # Output a topic with fancy title and bright white text.
    def print_out(options = {})
      defaults = { single: false, header: true }
      opt = defaults.merge(options)

      output = []
      if opt[:header]
        output.push(@title.format_header)
        output.push('')
      end
      topic = @content.dup
      topic.gsub!(/(?mi)^(`{3,})run([?!]*) *([^\n]*)[\s\S]*?\n\1\s*$/, '@@@run\2 \3') unless Howzit.options[:show_all_code]
      topic.split(/\n/).each do |l|
        case l
        when /@(before|after|prereq|end)/
          next
        when /@include(?<optional>[!?]{1,2})?\((?<action>.*?)\)/
          m = Regexp.last_match.named_captures.symbolize_keys
          matches = Howzit.buildnote.find_topic(m[:action])
          unless matches.empty?
            i_topic = matches[0]
            rule = '{kKd}'
            color = '{Kyd}'
            option = if i_topic.tasks.empty?
                       ''
                     else
                       optional = m[:optional] =~ /[?!]+/ ? true : false
                       default = m[:optional] =~ /!/ ? false : true
                       if optional
                         default ? " {xKk}[{gbK}Y{xKk}/{dbwK}n{xKk}]{x}#{color}".c : " {xKk}[{dbwK}y{xKk}/{bgK}N{xKk}]{x}#{color}".c
                       else
                         ''
                       end
                     end
            title = "#{opt[:single] ? 'From' : 'Include'} #{i_topic.title}#{option}:"
            options = { color: color, hr: '.', border: rule }
            unless Howzit.inclusions.include?(i_topic)
              output.push("#{'> ' * @nest_level}#{title}".format_header(options))
            end

            if opt[:single] && Howzit.inclusions.include?(i_topic)
              output.push("#{'> ' * @nest_level}#{title} included above".format_header(options))
            elsif opt[:single]
              @nest_level += 1
              output.concat(i_topic.print_out({ single: true, header: false }))
              output.push("#{'> ' * @nest_level}...".format_header(options))
              @nest_level -= 1
            end
            Howzit.inclusions.push(i_topic)
          end
        when /@(?<cmd>run|copy|open|url|include)(?<optional>[?!]{1,2})?\((?<action>.*?)\) *(?<title>.*?)$/
          m = Regexp.last_match.named_captures.symbolize_keys
          cmd = m[:cmd]
          obj = m[:action]
          title = m[:title].empty? ? obj : m[:title].strip
          optional = m[:optional] =~ /[?!]+/ ? true : false
          default = m[:optional] =~ /!/ ? false : true
          option = if optional
                     default ? ' {xk}[{g}Y{xk}/{dbw}n{xk}]{x}'.c : ' {xk}[{dbw}y{xk}/{g}N{xk}]{x}'.c
                   else
                     ''
                   end
          icon = case cmd
                 when 'run'
                   "\u{25B6}"
                 when 'copy'
                   "\u{271A}"
                 when /open|url/
                   "\u{279A}"
                 end

          output.push("{bmK}#{icon} {bwK}#{title.gsub(/\\n/, '\​n')}{x}#{option}".c)
        when /(?<fence>`{3,})run(?<optional>[!?]{1,2})? *(?<title>.*?)$/i
          m = Regexp.last_match.named_captures.symbolize_keys
          optional = m[:optional] =~ /[?!]+/ ? true : false
          default = m[:optional] =~ /!/ ? false : true
          option = if optional
                     default ? ' {xk}[{g}Y{xk}/{dbw}n{xk}]{x}'.c : ' {xk}[{dbw}y{xk}/{g}N{xk}]{x}'.c
                   else
                     ''
                   end
          desc = m[:title].length.positive? ? "Block: #{m[:title]}#{option}" : "Code Block#{option}"
          output.push("{bmK}\u{25B6} {bwK}#{desc}{x}\n```".c)
        when /@@@run(?<optional>[!?]{1,2})? *(?<title>.*?)$/i
          m = Regexp.last_match.named_captures.symbolize_keys
          optional = m[:optional] =~ /[?!]+/ ? true : false
          default = m[:optional] =~ /!/ ? false : true
          option = if optional
                     default ? ' {xk}[{g}Y{xk}/{dbw}n{xk}]{x}'.c : ' {xk}[{dbw}y{xk}/{g}N{xk}]{x}'.c
                   else
                     ''
                   end
          desc = m[:title].length.positive? ? "Block: #{m[:title]}#{option}" : "Code Block#{option}"
          output.push("{bmK}\u{25B6} {bwK}#{desc}{x}".c)
        else
          l.wrap!(Howzit.options[:wrap]) if Howzit.options[:wrap].positive?
          output.push(l)
        end
      end
      output.push('')
    end

    private

    def gather_tasks
      runnable = []
      @prereqs = @content.scan(/(?<=@before\n).*?(?=\n@end)/im).map(&:strip)
      @postreqs = @content.scan(/(?<=@after\n).*?(?=\n@end)/im).map(&:strip)

      rx = /(?mix)(?:
            @(?<cmd>include|run|copy|open|url)(?<optional>[!?]{1,2})?\((?<action>[^)]*?)\) *(?<title>[^\n]+)?
            |(?<fence>`{3,})run(?<optional2>[!?]{1,2})?(?:\s*(?<title2>[^\n]+))?(?<block>.*?)\k<fence>
            )/
      matches = []
      @content.scan(rx) { matches << Regexp.last_match }
      matches.each do |m|
        c = m.named_captures.symbolize_keys

        if c[:cmd].nil?
          optional = c[:optional2] =~ /[?!]{1,2}/ ? true : false
          default = c[:optional2] =~ /!/ ? false : true
          title = c[:title2].nil? ? '' : c[:title2].strip
          block = c[:block]&.strip
          runnable << Howzit::Task.new(:block, title, block, optional: optional, default: default)
        else
          cmd = c[:cmd]
          optional = c[:optional] =~ /[?!]{1,2}/ ? true : false
          default = c[:optional] =~ /!/ ? false : true
          obj = c[:action]
          title = c[:title].nil? ? obj : c[:title].strip

          case cmd
          when /include/i
            # matches = Howzit.buildnote.find_topic(obj)
            # unless matches.empty? || Howzit.inclusions.include?(matches[0].title)
            #   tasks = matches[0].tasks.map do |inc|
            #     Howzit.inclusions.push(matches[0].title)
            #     inc.parent = matches[0]
            #     inc
            #   end
            #   runnable.concat(tasks)
            # end
            runnable << Howzit::Task.new(:include, title, obj, optional: optional, default: default)
          when /run/i
            # warn "{bg}Running {bw}#{obj}{x}".c if Howzit.options[:log_level] < 2
            runnable << Howzit::Task.new(:run, title, obj, optional: optional, default: default)
          when /copy/i
            # warn "{bg}Copied {bw}#{obj}{bg} to clipboard{x}".c if Howzit.options[:log_level] < 2
            runnable << Howzit::Task.new(:copy, title, Shellwords.escape(obj), optional: optional, default: default)
          when /open|url/i
            runnable << Howzit::Task.new(:open, title, obj, optional: optional, default: default)
          end
        end
      end

      runnable
    end
  end
end
