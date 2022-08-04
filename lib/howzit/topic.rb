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
          res = Prompt.yn('This task has prerequisites, have they been met?', default: true)
          Process.exit 1 unless res

        end

        @tasks.each do |task|
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
        warn "{r}--run: No {br}@directive{xr} found in {bw}#{key}{x}".c
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
      topic.gsub!(/(?mi)^(`{3,})run *([^\n]*)[\s\S]*?\n\1\s*$/, '@@@run \2') unless Howzit.options[:show_all_code]
      topic.split(/\n/).each do |l|
        case l
        when /@(before|after|prereq|end)/
          next
        when /@include\((.*?)\)/
          m = Regexp.last_match
          matches = Howzit.buildnote.find_topic(m[1])
          unless matches.empty?
            if opt[:single]
              title = "From #{matches[0].title}:"
              color = '{Kyd}'
              rule = '{kKd}'
            else
              title = "Include #{matches[0].title}"
              color = '{Kyd}'
              rule = '{kKd}'
            end
            unless Howzit.inclusions.include?(matches[0])
              output.push("#{'> ' * @nest_level}#{title}".format_header({ color: color, hr: '.', border: rule }))
            end

            if opt[:single]
              if Howzit.inclusions.include?(matches[0])
                output.push("#{'> ' * @nest_level}#{title} included above".format_header({
                  color: color, hr: '.', border: rule }))
              else
                @nest_level += 1
                output.concat(matches[0].print_out({ single: true, header: false }))
                @nest_level -= 1
              end
              unless Howzit.inclusions.include?(matches[0])
                output.push("#{'> ' * @nest_level}...".format_header({ color: color, hr: '.', border: rule }))
              end
            end
            Howzit.inclusions.push(matches[0])
          end

        when /@(run|copy|open|url|include)\((.*?)\)(.*?)$/
          m = Regexp.last_match
          cmd = m[1]
          obj = m[2]
          title = m[3].empty? ? obj : m[3]
          icon = case cmd
                 when 'run'
                   "\u{25B6}"
                 when 'copy'
                   "\u{271A}"
                 when /open|url/
                   "\u{279A}"
                 end

          output.push("{bmK}#{icon} {bwK}#{title.gsub(/\\n/, '\​n')}{x}".c)
        when /(`{3,})run *(.*?)$/i
          m = Regexp.last_match
          desc = m[2].length.positive? ? "Block: #{m[2]}" : 'Code Block'
          output.push("{bmK}\u{25B6} {bwK}#{desc}{x}\n```".c)
        when /@@@run *(.*?)$/i
          m = Regexp.last_match
          desc = m[1].length.positive? ? "Block: #{m[1]}" : 'Code Block'
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

      rx = /(?:@(include|run|copy|open|url)\((.*?)\) *(.*?)(?=$)|(`{3,})run(?: +([^\n]+))?(.*?)\4)/mi
      directives = @content.scan(rx)

      directives.each do |c|
        if c[0].nil?
          title = c[4] ? c[4].strip : ''
          block = c[5].strip
          runnable << Howzit::Task.new(:block, title, block)
        else
          cmd = c[0]
          obj = c[1]
          title = c[3] || obj

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
            title = c[3] || obj
            runnable << Howzit::Task.new(:include, title, obj)
          when /run/i
            title = c[3] || obj
            # warn "{bg}Running {bw}#{obj}{x}".c if Howzit.options[:log_level] < 2
            runnable << Howzit::Task.new(:run, title, obj)
          when /copy/i
            # warn "{bg}Copied {bw}#{obj}{bg} to clipboard{x}".c if Howzit.options[:log_level] < 2
            runnable << Howzit::Task.new(:copy, title, Shellwords.escape(obj))
          when /open|url/i
            runnable << Howzit::Task.new(:open, title, obj)
          end
        end
      end

      runnable
    end
  end
end
