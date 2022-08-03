# frozen_string_literal: true

module Howzit
  # BuildNote Class
  class BuildNote
    attr_accessor :topics

    attr_reader :metadata, :title

    def initialize(file: nil, args: [])
      @topics = []
      @metadata = {}

      read_help(file)
    end

    def inspect
      puts "#<Howzit::BuildNote @topics=[#{@topics.count}]>"
    end

    def run
      process
    end

    def edit
      edit_note
    end

    def find_topic(term)
      @topics.filter do |topic|
        rx = term.to_rx
        topic.title.downcase =~ rx
      end
    end

    def grep(term)
      @topics.filter { |topic| topic.grep(term) }
    end

    # Output a list of topic titles
    def list
      output = []
      output.push(Color.template("{bg}Topics:{x}\n"))
      @topics.each do |topic|
        output.push(Color.template("- {bw}#{topic.title}{x}"))
      end
      output.join("\n")
    end

    def list_topics
      @topics.map { |topic| topic.title }
    end

    def list_completions
      list_topics.join("\n")
    end

    def list_runnable_completions
      output = []
      @topics.each do |topic|
        output.push(topic.title) if topic.tasks.count.positive?
      end
      output.join("\n")
    end

    def list_runnable
      output = []
      output.push(Color.template(%({bg}"Runnable" Topics:{x}\n)))
      @topics.each do |topic|
        s_out = []

        topic.tasks.each do |task|
          s_out.push(task.to_list)
        end

        unless s_out.empty?
          output.push(Color.template("- {bw}#{topic.title}{x}"))
          output.push(s_out.join("\n"))
        end
      end
      output.join("\n")
    end

    def read_file(file)
      read_help_file(file)
    end

    # Create a buildnotes skeleton
    def create_note
      trap('SIGINT') do
        warn "\nCanceled"
        exit!
      end
      default = !$stdout.isatty || Howzit.options[:default]
      # First make sure there isn't already a buildnotes file
      if note_file
        fname = Color.template("{by}#{note_file}{bw}")
        unless default
          res = Prompt.yn("#{fname} exists and appears to be a build note, continue anyway?", false)
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
        res = Prompt.yn("Are you absolutely sure you want to overwrite #{file}", false)

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

    def note_file
      @note_file ||= find_note_file
    end

    private

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
      return false if Howzit.config.should_ignore(filename)
      true
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

    def find_note_file
      filename = glob_note

      if filename.nil? && 'git'.available?
        proj_dir = `git rev-parse --show-toplevel 2>/dev/null`.strip
        unless proj_dir == ''
          Dir.chdir(proj_dir)
          filename = glob_note
        end
      end

      if filename.nil? && Howzit.options[:include_upstream]
        upstream_notes = glob_upstream
        filename = upstream_notes[-1] unless upstream_notes.empty?
      end

      return nil if filename.nil?

      File.expand_path(filename)
    end

    def read_upstream
      buildnotes = glob_upstream

      topics_dict = []
      buildnotes.each do |path|
        topics_dict.concat(read_help_file(path))
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

      template_topics = []

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
            template = File.join(Howzit.config.template_folder, t_file)
            if File.exist?(template)
              ensure_requirements(template)

              t_topics = BuildNote.new(file: template)
              if tasks
                tasks.each do |task|
                  t_topics.topics.each do |topic|
                    if topic.title =~ /^(.*?:)?#{task}$/i
                      topic.parent = t
                      template_topics.push(topic)
                    end
                  end
                end
              else
                t_topics.topics.map! do |topic|
                  topic.parent = t
                  topic
                end

                template_topics.concat(t_topics.topics)
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

    def note_title(truncate = 0)
      help = IO.read(note_file).strip
      title = help.match(/(?:^(\S.*?)(?=\n==)|^# ?(.*?)$)/)
      title = if title
                title[1].nil? ? title[2] : title[1]
              else
                note_file.sub(/(\.\w+)?$/, '')
              end

      title && truncate.positive? ? title.trunc(truncate) : title
    end

    # Read in the build notes file and output a hash of "Title" => contents
    def read_help_file(path = nil)
      topics = []

      filename = path.nil? ? note_file : path

      help = IO.read(filename)

      @title = note_title

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
          if path =~ /#{Howzit.config.template_folder}/
            short_path = File.basename(path, '.md')
          else
            home = ENV['HOME']
            short_path = File.dirname(path.sub(/^#{home}/, '~'))
            prefix = "_from #{short_path}_\n\n"
          end
          title = "#{short_path}:#{title}"
        end
        topic = Topic.new(title, prefix + lines.join("\n").strip.render_template(@metadata))
        topics.push(topic)
      end

      template_topics.each do |topic|
        topics.push(topic) unless find_topic(topic.title.sub(/^.+:/, '')).count.positive?
      end

      topics
    end

    def read_help(path = nil)
      @topics = read_help_file(path)
      return unless path.nil? && Howzit.options[:include_upstream]

      upstream_topics = read_upstream

      upstream_topics.each do |topic|
        @topics.push(topic) unless find_topic(title.sub(/^.+:/, '')).count.positive?
      end
    end

    def edit_note
      editor = Howzit.options.fetch(:editor, ENV['EDITOR'])

      raise 'No editor defined' if editor.nil?

      raise "Invalid editor (#{editor})" unless Util.valid_command?(editor)

      if note_file.nil?
        res = Prompt.yn('No build notes file found, create one?', true)

        create_note if res
        edit_note
      else
        `#{editor} "#{note_file}"`
      end
    end

    def process_topic(topic, run, single = false)
      new_topic = topic.dup

      # Handle variable replacement

      unless Howzit.arguments.empty?
        new_topic.content = new_topic.content.gsub(/\$(\d+)/) do |m|
          idx = m[1].to_i - 1
          Howzit.arguments.length > idx ? Howzit.arguments[idx] : m
        end
        new_topic.content = new_topic.content.gsub(/\$[@*]/, Shellwords.join(Howzit.arguments))
      end

      output = if run
                 new_topic.run
               else
                 new_topic.print_out({ single: single })
               end
      output.nil? ? '' : output.join("\n")
    end

    def process
      output = []

      unless note_file
        Process.exit 0 if Howzit.options[:list_runnable_titles] || Howzit.options[:list_topic_titles]

        # clear the buffer
        ARGV.length.times do
          ARGV.shift
        end
        res = yn("No build notes file found, create one?", true)
        create_note if res
        Process.exit 1
      end

      if Howzit.options[:title_only]
        out = note_title(20)
        $stdout.print(out.strip)
        Process.exit(0)
      elsif Howzit.options[:output_title] && !Howzit.options[:run]
        if @title && !@title.empty?
          header = @title.format_header({ hr: "\u{2550}", color: '{bwK}' })
          output.push("#{header}\n")
        end
      end

      if Howzit.options[:list_runnable]
        if Howzit.options[:list_runnable_titles]
          out = list_runnable_completions
          $stdout.print(out.strip)
        else
          out = list_runnable
          Util.show(out, { color: Howzit.options[:color], paginate: false, highlight: false })
        end
        Process.exit(0)
      end

      if Howzit.options[:list_topics]
        if Howzit.options[:list_topic_titles]
          $stdout.print(list_completions)
        else
          out = list
          Util.show(out, { color: Howzit.options[:color], paginate: false, highlight: false })
        end
        Process.exit(0)
      end

      topic_matches = []
      if Howzit.options[:grep]
        matches = grep_topics(Howzit.options[:grep])
        case Howzit.options[:multiple_matches]
        when :all
          topic_matches.concat(matches.sort)
        else
          topic_matches.concat(Prompt.choose(matches))
        end
      elsif Howzit.options[:choose]
        titles = Prompt.choose(list_topics)
        titles.each { |title| topic_matches.push(find_topic(title)[0]) }
      # If there are arguments use those to search for a matching topic
      elsif !Howzit.cli_args.empty?
        search = Howzit.cli_args.join(' ').strip.downcase.split(/ *, */).map(&:strip)

        search.each do |s|
          matches = find_topic(s)

          if matches.empty?
            output.push(Color.template(%({bR}ERROR:{xr} No topic match found for {bw}#{s}{x}\n)))
          else
            case Howzit.options[:multiple_matches]
            when :first
              topic_matches.push(matches[0])
            when :best
              topic_matches.push(matches.sort.min_by { |t| t.title.length })
            when :all
              topic_matches.concat(matches)
            else
              titles = matches.map { |topic| topic.title }
              res = Prompt.choose(titles)
              res.each { |title| topic_matches.concat(find_topic(title)) }
            end
          end
        end

        if topic_matches.empty? && !Howzit.options[:show_all_on_error]
          Util.show(output.join("\n"), { color: true, highlight: false, paginate: false, wrap: 0 })
          Process.exit 1
        end
      end

      if !topic_matches.empty?
        # If we found a match
        topic_matches.each { |topic_match| output.push(process_topic(topic_match, Howzit.options[:run], true)) }
      else
        # If there's no argument or no match found, output all
        topics.each { |k| output.push(process_topic(k, false, false)) }
      end
      Howzit.options[:paginate] = false if Howzit.options[:run]
      Util.show(output.join("\n").strip, Howzit.options)
    end
  end
end
