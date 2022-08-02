module Howzit
  # Primary Class for this module
  class BuildNotes
    include Prompt
    include Color

    attr_accessor :cli_args, :options, :arguments, :metadata

    def topics
      @topics ||= read_help
    end

    # If either mdless or mdcat are installed, use that for highlighting
    # markdown
    def which_highlighter
      if @options[:highlighter] =~ /auto/i
        highlighters = %w[mdcat mdless]
        highlighters.delete_if(&:nil?).select!(&:available?)
        return nil if highlighters.empty?

        hl = highlighters.first
        args = case hl
               when 'mdless'
                 '--no-pager'
               end

        [hl, args].join(' ')
      else
        hl = @options[:highlighter].split(/ /)[0]
        if hl.available?
          @options[:highlighter]
        else
          warn 'Specified highlighter not found, switching to auto' if @options[:log_level] < 2
          @options[:highlighter] = 'auto'
          which_highlighter
        end
      end
    end

    # When pagination is enabled, find the best (in my opinion) option,
    # favoring environment settings
    def which_pager
      if @options[:pager] =~ /auto/i
        pagers = [ENV['PAGER'], ENV['GIT_PAGER'],
                  'bat', 'less', 'more', 'pager']
        pagers.delete_if(&:nil?).select!(&:available?)
        return nil if pagers.empty?

        pg = pagers.first
        args = case pg
               when 'delta'
                 '--pager="less -FXr"'
               when /^(less|more)$/
                 '-FXr'
               when 'bat'
                 if @options[:highlight]
                   '--language Markdown --style plain --pager="less -FXr"'
                 else
                   '--style plain --pager="less -FXr"'
                 end
               else
                 ''
               end

        [pg, args].join(' ')
      else
        pg = @options[:pager].split(/ /)[0]
        if pg.available?
          @options[:pager]
        else
          warn 'Specified pager not found, switching to auto' if @options[:log_level] < 2
          @options[:pager] = 'auto'
          which_pager
        end
      end
    end

    # Paginate the output
    def page(text)
      read_io, write_io = IO.pipe

      input = $stdin

      pid = Kernel.fork do
        write_io.close
        input.reopen(read_io)
        read_io.close

        # Wait until we have input before we start the pager
        IO.select [input]

        pager = which_pager
        begin
          exec(pager)
        rescue SystemCallError => e
          @log.error(e)
          exit 1
        end
      end

      read_io.close
      write_io.write(text)
      write_io.close

      _, status = Process.waitpid2(pid)
      status.success?
    end

    # print output to terminal
    def show(string, opts = {})
      options = {
        color: true,
        highlight: false,
        wrap: 0
      }

      options.merge!(opts)

      string = string.uncolor unless options[:color]

      pipes = ''
      if options[:highlight]
        hl = which_highlighter
        pipes = "|#{hl}" if hl
      end

      output = `echo #{Shellwords.escape(string.strip)}#{pipes}`.strip

      if @options[:paginate]
        page(output)
      else
        puts output
      end
    end

    def should_mark_iterm?
      ENV['TERM_PROGRAM'] =~ /^iTerm/ && !@options[:run] && !@options[:paginate]
    end

    def iterm_marker
      "\e]1337;SetMark\a" if should_mark_iterm?
    end

    def color_single_options(choices = %w[y n])
      out = []
      choices.each do |choice|
        case choice
        when /[A-Z]/
          out.push(Color.template("{bg}#{choice}{xg}"))
        else
          out.push(Color.template("{w}#{choice}"))
        end
      end
      Color.template("{g}[#{out.join('/')}{g}]{x}")
    end

    # Create a buildnotes skeleton
    def create_note
      trap('SIGINT') do
        warn "\nCanceled"
        exit!
      end
      default = !$stdout.isatty || @options[:default]
      # First make sure there isn't already a buildnotes file
      if note_file
        fname = Color.template("{by}#{note_file}{bw}")
        unless default
          res = yn("#{fname} exists and appears to be a build note, continue anyway?", false)
          unless res
            puts 'Canceled'
            Process.exit 0
          end
        end
      end

      title = File.basename(Dir.pwd)
      if default
        input = title
      else
        printf Color.template("{bw}Project name {xg}[#{title}]{bw}: {x}")
        input = $stdin.gets.chomp
        title = input unless input.empty?
      end
      summary = ''
      unless default
        printf Color.template('{bw}Project summary: {x}')
        input = $stdin.gets.chomp
        summary = input unless input.empty?
      end

      fname = 'buildnotes.md'
      unless default
        printf Color.template("{bw}Build notes filename (must begin with 'howzit' or 'build')\n{xg}[#{fname}]{bw}: {x}")
        input = $stdin.gets.chomp
        fname = input unless input.empty?
      end

      note = <<~EOBUILDNOTES
        # #{title}

        #{summary}

        ## File Structure

        Where are the main editable files? Is there a dist/build folder that should be ignored?

        ## Build

        What build system/parameters does this use?

        @run(./build command)

        ## Deploy

        What are the procedures/commands to deploy this project?

        ## Other

        Version control notes, additional gulp/rake/make/etc tasks...

      EOBUILDNOTES

      if File.exist?(fname) && !default
        file = Color.template("{by}#{fname}")
        res = yn("Are you absolutely sure you want to overwrite #{file}", false)

        unless res
          puts 'Canceled'
          Process.exit 0
        end
      end

      File.open(fname, 'w') do |f|
        f.puts note
        puts Color.template("{by}Build notes for #{title} written to #{fname}")
      end
    end

    # Make a fancy title line for the topic
    def format_header(title, opts = {})
      options = {
        hr: "\u{254C}",
        color: '{bg}',
        border: '{x}',
        mark: false
      }

      options.merge!(opts)

      case @options[:header_format]
      when :block
        Color.template("#{options[:color]}\u{258C}#{title}#{should_mark_iterm? && options[:mark] ? iterm_marker : ''}{x}")
      else
        cols = TTY::Screen.columns

        cols = @options[:wrap] if (@options[:wrap]).positive? && cols > @options[:wrap]
        title = Color.template("#{options[:border]}#{options[:hr] * 2}( #{options[:color]}#{title}#{options[:border]} )")

        tail = if should_mark_iterm?
                 "#{options[:hr] * (cols - title.uncolor.length - 15)}#{options[:mark] ? iterm_marker : ''}"
               else
                 options[:hr] * (cols - title.uncolor.length)
               end
        Color.template("#{title}#{tail}{x}")
      end
    end

    def os_open(command)
      os = RbConfig::CONFIG['target_os']
      out = Color.template("{bg}Opening {bw}#{command}")
      case os
      when /darwin.*/i
        warn Color.template("#{out} (macOS){x}") if @options[:log_level] < 2
        `open #{Shellwords.escape(command)}`
      when /mingw|mswin/i
        warn Color.template("#{out} (Windows){x}") if @options[:log_level] < 2
        `start #{Shellwords.escape(command)}`
      else
        if 'xdg-open'.available?
          warn Color.template("#{out} (Linux){x}") if @options[:log_level] < 2
          `xdg-open #{Shellwords.escape(command)}`
        else
          warn out if @options[:log_level] < 2
          warn 'Unable to determine executable for `open`.'
        end
      end
    end

    def grep_topics(pat)
      matching_topics = []
      topics.each do |topic, content|
        if content =~ /#{pat}/i || topic =~ /#{pat}/i
          matching_topics.push(topic)
        end
      end
      matching_topics
    end

    # Handle run command, execute directives
    def run_topic(key)
      output = []
      tasks = 0
      if topics[key] =~ /(@(include|run|copy|open|url)\((.*?)\)|`{3,}run)/i
        prereqs = topics[key].scan(/(?<=@before\n).*?(?=\n@end)/im).map(&:strip)
        postreqs = topics[key].scan(/(?<=@after\n).*?(?=\n@end)/im).map(&:strip)

        unless prereqs.empty?
          puts prereqs.join("\n\n")
          res = yn('This task has prerequisites, have they been met?', true)
          Process.exit 1 unless res

        end
        directives = topics[key].scan(/(?:@(include|run|copy|open|url)\((.*?)\)|(`{3,})run(?: +([^\n]+))?(.*?)\3)/mi)

        tasks += directives.length
        directives.each do |c|
          if c[0].nil?
            title = c[3] ? c[3].strip : ''
            warn Color.template("{bg}Running block {bw}#{title}{x}") if @options[:log_level] < 2
            block = c[4].strip
            script = Tempfile.new('howzit_script')
            begin
              script.write(block)
              script.close
              File.chmod(0777, script.path)
              system(%(/bin/sh -c "#{script.path}"))
            ensure
              script.close
              script.unlink
            end
          else
            cmd = c[0]
            obj = c[1]
            case cmd
            when /include/i
              matches = match_topic(obj)
              if matches.empty?
                warn "No topic match for @include(#{search})"
              else
                if @included.include?(matches[0])
                  warn Color.template("{by}Tasks from {bw}#{matches[0]} already included, skipping{x}") if @options[:log_level] < 2
                else
                  warn Color.template("{by}Including tasks from {bw}#{matches[0]}{x}") if @options[:log_level] < 2
                  process_topic(matches[0], true)
                  warn Color.template("{by}End include {bw}#{matches[0]}{x}") if @options[:log_level] < 2
                end
              end
            when /run/i
              warn Color.template("{bg}Running {bw}#{obj}{x}") if @options[:log_level] < 2
              system(obj)
            when /copy/i
              warn Color.template("{bg}Copied {bw}#{obj}{bg} to clipboard{x}") if @options[:log_level] < 2
              `echo #{Shellwords.escape(obj)}'\\c'|pbcopy`
            when /open|url/i
              os_open(obj)
            end
          end
        end
      else
        warn Color.template("{r}--run: No {br}@directive{xr} found in {bw}#{key}{x}")
      end
      output.push("Ran #{tasks} #{tasks == 1 ? 'task' : 'tasks'}") if @options[:log_level] < 2

      puts postreqs.join("\n\n") unless postreqs.empty?

      output
    end

    # Output a topic with fancy title and bright white text.
    def output_topic(key, options = {})
      defaults = { single: false, header: true }
      opt = defaults.merge(options)

      output = []
      if opt[:header]
        output.push(format_header(key, { mark: should_mark_iterm? }))
        output.push('')
      end
      topic = topics[key].strip
      topic.gsub!(/(?mi)^(`{3,})run *([^\n]*)[\s\S]*?\n\1\s*$/, '@@@run \2') unless @options[:show_all_code]
      topic.split(/\n/).each do |l|
        case l
        when /@(before|after|prereq|end)/
          next
        when /@include\((.*?)\)/

          m = Regexp.last_match
          matches = match_topic(m[1])
          unless matches.empty?
            if opt[:single]
              title = "From #{matches[0]}:"
              color = '{Kyd}'
              rule = '{kKd}'
            else
              title = "Include #{matches[0]}"
              color = '{Kyd}'
              rule = '{kKd}'
            end
            output.push(format_header("#{'> ' * @nest_level}#{title}", { color: color, hr: '.', border: rule })) unless @included.include?(matches[0])

            if opt[:single]
              if @included.include?(matches[0])
                output.push(format_header("#{'> ' * @nest_level}#{title} included above", { color: color, hr: '.', border: rule }))
              else
                @nest_level += 1
                output.concat(output_topic(matches[0], {single: true, header: false}))
                @nest_level -= 1
              end
              output.push(format_header("#{'> ' * @nest_level}...", { color: color, hr: '.', border: rule })) unless @included.include?(matches[0])
            end
            @included.push(matches[0])
          end

        when /@(run|copy|open|url|include)\((.*?)\)/
          m = Regexp.last_match
          cmd = m[1]
          obj = m[2]
          icon = case cmd
                 when 'run'
                   "\u{25B6}"
                 when 'copy'
                   "\u{271A}"
                 when /open|url/
                   "\u{279A}"
                 end
          output.push(Color.template("{bmK}#{icon} {bwK}#{obj}{x}"))
        when /(`{3,})run *(.*?)$/i
          m = Regexp.last_match
          desc = m[2].length.positive? ? "Block: #{m[2]}" : 'Code Block'
          output.push(Color.template("{bmK}\u{25B6} {bwK}#{desc}{x}\n```"))
        when /@@@run *(.*?)$/i
          m = Regexp.last_match
          desc = m[1].length.positive? ? "Block: #{m[1]}" : 'Code Block'
          output.push(Color.template("{bmK}\u{25B6} {bwK}#{desc}{x}"))
        else
          l.wrap!(@options[:wrap]) if (@options[:wrap]).positive?
          output.push(l)
        end
      end
      output.push('')
    end

    def process_topic(key, run, single = false)
      # Handle variable replacement
      content = topics[key]
      unless @arguments.empty?
        content.gsub!(/\$(\d+)/) do |m|
          idx = m[1].to_i - 1
          @arguments.length > idx ? @arguments[idx] : m
        end
        content.gsub!(/\$[@*]/, Shellwords.join(@arguments))
      end

      output = if run
                 run_topic(key)
               else
                 output_topic(key, {single: single})
               end
      output.nil? ? '' : output.join("\n")
    end

    # Output a list of topic titles
    def list_topics
      output = []
      output.push(Color.template("{bg}Topics:{x}\n"))
      topics.each_key do |title|
        output.push(Color.template("- {bw}#{title}{x}"))
      end
      output.join("\n")
    end

    # Output a list of topic titles for shell completion
    def list_topic_titles
      topics.keys.join("\n")
    end

    def get_note_title(truncate = 0)
      title = nil
      help = IO.read(note_file).strip
      title = help.match(/(?:^(\S.*?)(?=\n==)|^# ?(.*?)$)/)
      title = if title
                title[1].nil? ? title[2] : title[1]
              else
               note_file.sub(/(\.\w+)?$/, '')
             end

      title && truncate.positive? ? title.trunc(truncate) : title
    end

    def list_runnable_titles
      output = []
      topics.each do |title, sect|
        runnable = false
        sect.split(/\n/).each do |l|
          if l =~ /(@(run|copy|open|url)\((.*?)\)|`{3,}run)/
            runnable = true
            break
          end
        end
        output.push(title) if runnable
      end
      output.join("\n")
    end

    def list_runnable
      output = []
      output.push(Color.template(%({bg}"Runnable" Topics:{x}\n)))
      topics.each do |title, sect|
        s_out = []
        lines = sect.split(/\n/)
        lines.each do |l|
          case l
          when /@run\((.*?)\)(.*)?/
            m = Regexp.last_match
            run = m[2].strip.length.positive? ? m[2].strip : m[1]
            s_out.push("    * run: #{run.gsub(/\\n/, '\​n')}")
          when /@(copy|open|url)\((.*?)\)/
            m = Regexp.last_match
            s_out.push("    * #{m[1]}: #{m[2]}")
          when /`{3,}run(.*)?/m
            run = '    * run code block'
            title = Regexp.last_match(1).strip
            run += " (#{title})" if title.length.positive?
            s_out.push(run)
          end
        end
        unless s_out.empty?
          output.push(Color.template("- {bw}#{title}{x}"))
          output.push(s_out.join("\n"))
        end
      end
      output.join("\n")
    end

    def read_upstream
      buildnotes = glob_upstream
      topics_dict = {}
      buildnotes.each do |path|
        topics_dict = topics_dict.merge(read_help_file(path))
      end
      topics_dict
    end

    def ensure_requirements(template)
      t_leader = IO.read(template).split(/^#/)[0].strip
      if t_leader.length > 0
        t_meta = t_leader.get_metadata
        if t_meta.key?('required')
          required = t_meta['required'].strip.split(/\s*,\s*/)
          required.each do |req|
            unless @metadata.keys.include?(req.downcase)
              warn Color.template(%({xr}ERROR: Missing required metadata key from template '{bw}#{File.basename(template, '.md')}{xr}'{x}))
              warn Color.template(%({xr}Please define {by}#{req.downcase}{xr} in build notes{x}))
              Process.exit 1
            end
          end
        end
      end
    end

    def get_template_topics(content)
      leader = content.split(/^#/)[0].strip

      template_topics = {}
      if leader.length > 0
        data = leader.get_metadata
        @metadata = @metadata.merge(data)

        if data.key?('template')
          templates = data['template'].strip.split(/\s*,\s*/)
          templates.each do |t|
            tasks = nil
            if t =~ /\[(.*?)\]$/
              tasks = Regexp.last_match[1].split(/\s*,\s*/).map {|t| t.gsub(/\*/, '.*?')}
              t = t.sub(/\[.*?\]$/, '').strip
            end

            t_file = t.sub(/(\.md)?$/, '.md')
            template = File.join(template_folder, t_file)
            if File.exist?(template)
              ensure_requirements(template)

              t_topics = read_help_file(template)
              if tasks
                tasks.each do |task|
                  t_topics.keys.each do |topic|
                    if topic =~ /^(.*?:)?#{task}$/i
                      template_topics[topic] = t_topics[topic]
                    end
                  end
                end
              else
                template_topics = template_topics.merge(t_topics)
              end
            end
          end
        end
      end
      template_topics
    end

    def include_file(m)
      file = File.expand_path(m[1])

      return m[0] unless File.exist?(file)

      content = IO.read(file)
      home = ENV['HOME']
      short_path = File.dirname(file.sub(/^#{home}/, '~'))
      prefix = "#{short_path}/#{File.basename(file)}:"
      parts = content.split(/^##+/)
      parts.shift
      if parts.empty?
        content
      else
        "## #{parts.join('## ')}".gsub(/^(##+ *)(?=\S)/, "\\1#{prefix}")
      end
    end

    # Read in the build notes file and output a hash of "Title" => contents
    def read_help_file(path = nil)
      filename = path.nil? ? note_file : path
      topics_dict = {}
      help = IO.read(filename)

      help.gsub!(/@include\((.*?)\)/) do
        include_file(Regexp.last_match)
      end

      template_topics = get_template_topics(help)

      split = help.split(/^##+/)
      split.slice!(0)
      split.each do |sect|
        next if sect.strip.empty?

        lines = sect.split(/\n/)
        title = lines.slice!(0).strip
        prefix = ''
        if path
          if path =~ /#{template_folder}/
            short_path = File.basename(path, '.md')
          else
            home = ENV['HOME']
            short_path = File.dirname(path.sub(/^#{home}/, '~'))
            prefix = "_from #{short_path}_\n\n"
          end
          title = "#{short_path}:#{title}"
        end
        topics_dict[title] = prefix + lines.join("\n").strip.render_template(@metadata)
      end

      template_topics.each do |title, content|
        unless topics_dict.key?(title.sub(/^.+:/, ''))
          topics_dict[title] = content
        end
      end

      topics_dict
    end

    def read_help
      topics = read_help_file
      if @options[:include_upstream]
        upstream_topics = read_upstream
        upstream_topics.each do |topic, content|
          unless topics.key?(topic.sub(/^.*?:/, ''))
            topics[topic] = content
          end
        end
        # topics = upstream_topics.merge(topics)
      end
      topics
    end


    def match_topic(search)
      matches = []

      rx = case @options[:matching]
           when 'exact'
             /^#{search}$/i
           when 'beginswith'
             /^#{search}/i
           when 'fuzzy'
             search = search.split(//).join('.*?') if @options[:matching] == 'fuzzy'
             /#{search}/i
           else
             /#{search}/i
           end

      topics.each_key do |k|
        matches.push(k) if k.downcase =~ rx
      end
      matches
    end

    def initialize(args = [])
      Color.coloring = $stdout.isatty
      flags = {
        run: false,
        list_topics: false,
        list_topic_titles: false,
        list_runnable: false,
        list_runnable_titles: false,
        title_only: false,
        choose: false,
        quiet: false,
        verbose: false,
        default: false,
        grep: nil
      }

      defaults = {
        color: true,
        highlight: true,
        paginate: true,
        wrap: 0,
        output_title: false,
        highlighter: 'auto',
        pager: 'auto',
        matching: 'partial', # exact, partial, fuzzy, beginswith
        show_all_on_error: false,
        include_upstream: false,
        show_all_code: false,
        multiple_matches: 'choose',
        header_format: 'border',
        log_level: 1 # 0: debug, 1: info, 2: warn, 3: error
      }

      @metadata = {}
      @included = []
      @nest_level = 0

      parts = Shellwords.shelljoin(args).split(/ -- /)
      args = parts[0] ? Shellwords.shellsplit(parts[0]) : []
      @arguments = parts[1] ? Shellwords.shellsplit(parts[1]) : []

      config = load_config(defaults)
      @options = flags.merge(config)

      OptionParser.new do |opts|
        opts.banner = "Usage: #{__FILE__} [OPTIONS] [TOPIC]"
        opts.separator ''
        opts.separator 'Show build notes for the current project (buildnotes.md).
        Include a topic name to see just that topic, or no argument to display all.'
        opts.separator ''
        opts.separator 'Options:'

        opts.on('-c', '--create', 'Create a skeleton build note in the current working directory') do
          create_note
          Process.exit 0
        end

        opts.on('-e', '--edit', "Edit buildnotes file in current working directory
                using $EDITOR") do
          edit_note
          Process.exit 0
        end

        opts.on('--grep PATTERN', 'Display sections matching a search pattern') do |pat|
          @options[:grep] = pat
        end

        opts.on('-L', '--list-completions', 'List topics for completion') do
          @options[:list_topics] = true
          @options[:list_topic_titles] = true
        end

        opts.on('-l', '--list', 'List available topics') do
          @options[:list_topics] = true
        end

        opts.on('-m', '--matching TYPE', MATCHING_OPTIONS,
                'Topics matching type', "(#{MATCHING_OPTIONS.join(', ')})") do |c|
          @options[:matching] = c
        end

        opts.on('--multiple TYPE', MULTIPLE_OPTIONS,
                'Multiple result handling', "(#{MULTIPLE_OPTIONS.join(', ')}, default choose)") do |c|
          @options[:multiple_matches] = c.to_sym
        end

        opts.on('-R', '--list-runnable', 'List topics containing @ directives (verbose)') do
          @options[:list_runnable] = true
        end

        opts.on('-r', '--run', 'Execute @run, @open, and/or @copy commands for given topic') do
          @options[:run] = true
        end

        opts.on('-s', '--select', 'Select topic from menu') do
          @options[:choose] = true
        end

        opts.on('-T', '--task-list', 'List topics containing @ directives (completion-compatible)') do
          @options[:list_runnable] = true
          @options[:list_runnable_titles] = true
        end

        opts.on('-t', '--title', 'Output title with build notes') do
          @options[:output_title] = true
        end

        opts.on('-q', '--quiet', 'Silence info message') do
          @options[:log_level] = 3
        end

        opts.on('-v', '--verbose', 'Show all messages') do
          @options[:log_level] = 0
        end

        opts.on('-u', '--[no-]upstream', 'Traverse up parent directories for additional build notes') do |p|
          @options[:include_upstream] = p
        end

        opts.on('--show-code', 'Display the content of fenced run blocks') do
          @options[:show_all_code] = true
        end

        opts.on('-w', '--wrap COLUMNS', 'Wrap to specified width (default 80, 0 to disable)') do |w|
          @options[:wrap] = w.to_i
        end

        opts.on('--config-get [KEY]', 'Display the configuration settings or setting for a specific key') do |k|

          if k.nil?
            config.sort_by { |key, _| key }.each do |key, val|
              print "#{key}: "
              p val
            end
          else
            k.sub!(/^:/, '')
            if config.key?(k.to_sym)
              puts config[k.to_sym]
            else
              puts "Key #{k} not found"
            end
          end
          Process.exit 0
        end

        opts.on('--config-set KEY=VALUE', 'Set a config value (must be a valid key)') do |key|
          raise 'Argument must be KEY=VALUE' unless key =~ /\S=\S/

          k, v = key.split(/=/)
          k.sub!(/^:/, '')

          if config.key?(k.to_sym)
            config[k.to_sym] = v.to_config_value(config[k.to_sym])
          else
            puts "Key #{k} not found"
          end
          write_config(config)
          Process.exit 0
        end

        opts.on('--edit-config', "Edit configuration file using default $EDITOR") do
          edit_config(defaults)
          Process.exit 0
        end

        opts.on('--title-only', 'Output title only') do
          @options[:output_title] = true
          @options[:title_only] = true
        end

        opts.on('--templates', 'List available templates') do
          Dir.chdir(template_folder)
          Dir.glob('*.md').each do |file|
            template = File.basename(file, '.md')
            puts Color.template("{Mk}template:{Yk}#{template}{x}")
            puts Color.template("{bk}[{bl}tasks{bk}]──────────────────────────────────────┐{x}")
            metadata = file.extract_metadata
            topics = read_help_file(file)
            topics.each_key do |topic|
              puts Color.template(" {bk}│{bw}-{x} {bcK}#{template}:#{topic.sub(/^.*?:/, '')}{x}")
            end
            if metadata.size > 0
              meta = []
              meta << metadata['required'].split(/\s*,\s*/).map {|m| "*{bw}#{m}{xw}" } if metadata.key?('required')
              meta << metadata['optional'].split(/\s*,\s*/).map {|m| "#{m}" } if metadata.key?('optional')
              puts Color.template("{bk}[{bl}meta{bk}]───────────────────────────────────────┤{x}")
              puts Color.template(" {bk}│ {xw}#{meta.join(", ")}{x}")
            end
            puts Color.template(" {bk}└───────────────────────────────────────────┘{x}")
          end
          Process.exit 0
        end

        opts.on('--header-format TYPE', HEADER_FORMAT_OPTIONS,
                "Formatting style for topic titles (#{HEADER_FORMAT_OPTIONS.join(', ')})") do |t|
          @options[:header_format] = t
        end

        opts.on('--[no-]color', 'Colorize output (default on)') do |c|
          @options[:color] = c
          @options[:highlight] = false unless c
        end

        opts.on('--[no-]md-highlight', 'Highlight Markdown syntax (default on), requires mdless or mdcat') do |m|
          @options[:highlight] = @options[:color] ? m : false
        end

        opts.on('--[no-]pager', 'Paginate output (default on)') do |p|
          @options[:paginate] = p
        end

        opts.on('-h', '--help', 'Display this screen') do
          puts opts
          Process.exit 0
        end

        opts.on('-v', '--version', 'Display version number') do
          puts "Howzit v#{VERSION}"
          Process.exit 0
        end

        opts.on('--default', 'Answer all prompts with default response') do
          @options[:default] = true
        end
      end.parse!(args)

      @options[:multiple_matches] = @options[:multiple_matches].to_sym
      @options[:header_format] = @options[:header_format].to_sym

      @cli_args = args
    end

    def edit_note
      raise 'No EDITOR variable defined in environment' if ENV['EDITOR'].nil?

      if note_file.nil?
        res = yn("No build notes file found, create one?", true)

        create_note if res
        edit_note
      else
        `#{ENV['EDITOR']} "#{note_file}"`
      end
    end

    ##
    ## Traverse up directory tree looking for build notes
    ##
    ## @return     topics dictionary
    ##
    def glob_upstream
      home = Dir.pwd
      dir = File.dirname(home)
      buildnotes = []
      filename = nil

      while dir != '/' && (dir =~ %r{[A-Z]:/}).nil?
        Dir.chdir(dir)
        filename = glob_note
        unless filename.nil?
          note = File.join(dir, filename)
          buildnotes.push(note) unless note == note_file
        end
        dir = File.dirname(dir)
      end

      Dir.chdir(home)

      buildnotes.reverse
    end

    def is_build_notes(filename)
      return false if filename.downcase !~ /(^howzit[^.]*|build[^.]+)/
      return false if should_ignore(filename)
      true
    end

    def should_ignore(filename)
      return false unless File.exist?(ignore_file)

      unless @ignore_patterns
        @ignore_patterns = YAML.load(IO.read(ignore_file))
      end

      ignore = false

      @ignore_patterns.each do |pat|
        if filename =~ /#{pat}/
          ignore = true
          break
        end
      end

      ignore
    end

    def glob_note
      filename = nil
      # Check for a build note file in the current folder. Filename must start
      # with "build" and have an extension of txt, md, or markdown.

      Dir.glob('*.{txt,md,markdown}').each do |f|
        if is_build_notes(f)
          filename = f
          break
        end
      end
      filename
    end

    def note_file
      @note_file ||= find_note_file
    end

    def find_note_file
      filename = glob_note

      if filename.nil? && 'git'.available?
        proj_dir = `git rev-parse --show-toplevel 2>/dev/null`.strip
        unless proj_dir == ''
          Dir.chdir(proj_dir)
          filename = glob_note
        end
      end

      if filename.nil? && @options[:include_upstream]
        upstream_notes = glob_upstream
        filename = upstream_notes[-1] unless upstream_notes.empty?
      end

      return nil if filename.nil?

      File.expand_path(filename)
    end

    def options_list(matches)
      counter = 1
      puts
      matches.each do |match|
        printf("%<counter>2d ) %<option>s\n", counter: counter, option: match)
        counter += 1
      end
      puts
    end

    def command_exist?(command)
      exts = ENV.fetch('PATHEXT', '').split(::File::PATH_SEPARATOR)
      if Pathname.new(command).absolute?
        ::File.exist?(command) ||
          exts.any? { |ext| ::File.exist?("#{command}#{ext}") }
      else
        ENV.fetch('PATH', '').split(::File::PATH_SEPARATOR).any? do |dir|
          file = ::File.join(dir, command)
          ::File.exist?(file) ||
            exts.any? { |ext| ::File.exist?("#{file}#{ext}") }
        end
      end
    end

    def choose(matches)
      if command_exist?('fzf')
        settings = [
          '-0',
          '-1',
          '-m',
          "--height=#{matches.count + 2}",
          '--header="Use tab to mark multiple selections, enter to display/run"',
          '--prompt="Select a section > "'
        ]
        res = `echo #{Shellwords.escape(matches.join("\n"))} | fzf #{settings.join(' ')}`.strip
        if res.nil? || res.empty?
          warn 'Cancelled'
          Process.exit 0
        end
        return res.split(/\n/)
      end

      res = matches[0..9]
      stty_save = `stty -g`.chomp

      trap('INT') do
        system('stty', stty_save)
        exit
      end

      options_list(matches)

      begin
        printf("Type 'q' to cancel, enter for first item", res.length)
        while (line = Readline.readline(': ', true))
          if line =~ /^[a-z]/i
            system('stty', stty_save) # Restore
            exit
          end
          line = line == '' ? 1 : line.to_i

          return matches[line - 1] if line.positive? && line <= matches.length

          puts 'Out of range'
          options_list(matches)
        end
      rescue Interrupt
        system('stty', stty_save)
        exit
      end
    end

    def config_dir
      File.expand_path(CONFIG_DIR)
    end

    def config_file
      File.join(config_dir, CONFIG_FILE)
    end

    def ignore_file
      File.join(config_dir, IGNORE_FILE)
    end

    def template_folder
      File.join(config_dir, 'templates')
    end

    def create_config(defaults)
      dir, file = [config_dir, config_file]
      unless File.directory?(dir)
        warn "Creating config directory at #{dir}"
        FileUtils.mkdir_p(dir)
      end

      unless File.exist?(file)
        warn "Writing fresh config file to #{file}"
        write_config(defaults)
      end
      file
    end

    def load_config(defaults)
      file = create_config(defaults)
      config = YAML.load(IO.read(file))
      newconfig = config ? defaults.merge(config) : defaults
      write_config(newconfig)
      newconfig
    end

    def write_config(config)
      File.open(config_file, 'w') { |f| f.puts config.to_yaml }
    end

    def edit_config(defaults)
      raise 'No EDITOR variable defined in environment' if ENV['EDITOR'].nil?

      load_config(defaults)
      `#{ENV['EDITOR']} "#{config_file}"`
    end

    def process
      output = []

      unless note_file
        Process.exit 0 if @options[:list_runnable_titles] || @options[:list_topic_titles]

        # clear the buffer
        ARGV.length.times do
          ARGV.shift
        end
        res = yn("No build notes file found, create one?", true)
        create_note if res
        Process.exit 1
      end

      if @options[:title_only]
        out = get_note_title(20)
        $stdout.print(out.strip)
        Process.exit(0)
      elsif @options[:output_title] && !@options[:run]
        title = get_note_title
        if title && !title.empty?
          header = format_header(title, { hr: "\u{2550}", color: '{bwK}' })
          output.push("#{header}\n")
        end
      end

      if @options[:list_runnable]
        if @options[:list_runnable_titles]
          out = list_runnable_titles
          $stdout.print(out.strip)
        else
          out = list_runnable
          show(out, { color: @options[:color], paginate: false, highlight: false })
        end
        Process.exit(0)
      end

      if @options[:list_topics]
        if @options[:list_topic_titles]
          $stdout.print(list_topic_titles)
        else
          out = list_topics
          show(out, { color: @options[:color], paginate: false, highlight: false })
        end
        Process.exit(0)
      end

      topic_matches = []
      if @options[:grep]
        matches = grep_topics(@options[:grep])
        case @options[:multiple_matches]
        when :all
          topic_matches.concat(matches.sort)
        else
          topic_matches.concat(choose(matches))
        end
      elsif @options[:choose]
        topic_matches.concat(choose(topics.keys))
      # If there are arguments use those to search for a matching topic
      elsif !@cli_args.empty?
        search = @cli_args.join(' ').strip.downcase.split(/ *, */).map(&:strip)

        search.each do |s|
          matches = match_topic(s)

          if matches.empty?
            output.push(Color.template(%({bR}ERROR:{xr} No topic match found for {bw}#{s}{x}\n)))
          else
            case @options[:multiple_matches]
            when :first
              topic_matches.push(matches[0])
            when :best
              topic_matches.push(matches.sort.min_by(&:length))
            when :all
              topic_matches.concat(matches)
            else
              topic_matches.concat(choose(matches))
            end
          end
        end

        if topic_matches.empty? && !@options[:show_all_on_error]
          show(output.join("\n"), { color: true, highlight: false, paginate: false, wrap: 0 })
          Process.exit 1
        end
      end

      if !topic_matches.empty?
        # If we found a match
        topic_matches.each { |topic_match| output.push(process_topic(topic_match, @options[:run], true)) }
      else
        # If there's no argument or no match found, output all
        topics.each_key { |k| output.push(process_topic(k, false, false)) }
      end
      @options[:paginate] = false if @options[:run]
      show(output.join("\n").strip, @options)
    end
  end
end
