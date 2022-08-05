# frozen_string_literal: true

module Howzit
  # BuildNote Class
  class BuildNote
    attr_accessor :topics

    attr_reader :metadata, :title

    ##
    ## Initialize a build note
    ##
    ## @param      file  [String] The path to the build note file
    ## @param      args  [Array] additional args
    ##
    def initialize(file: nil, args: [])
      @topics = []
      if note_file.nil?
        res = Prompt.yn('No build notes file found, create one?', default: true)

        create_note if res
        Process.exit 0
      end
      content = Util.read_file(note_file)
      if content.nil? || content.empty?
        Howzit.console.error("{br}No content found in build note (#{note_file}){x}".c)
        Process.exit 1
      else
        @metadata = content.split(/^#/)[0].strip.get_metadata
      end

      read_help(file)
    end

    def inspect
      puts "#<Howzit::BuildNote @topics=[#{@topics.count}]>"
    end

    ##
    ## Public method to begin processing the build note based on command line options
    ##
    def run
      process
    end

    ##
    ## Public method to open build note in editor
    ##
    def edit
      edit_note
    end

    ##
    ## Find a topic based on a fuzzy match
    ##
    ## @param      term  [String] The search term
    ##
    def find_topic(term)
      @topics.filter do |topic|
        rx = term.to_rx
        topic.title.downcase =~ rx
      end
    end

    ##
    ## Call grep on all topics, filtering out those that don't match
    ##
    ## @param      term  [String] The search pattern
    ##
    def grep(term)
      @topics.filter { |topic| topic.grep(term) }
    end

    # Output a list of topic titles
    #
    # @return     [String] formatted list of topics in build note
    #
    def list
      output = []
      output.push("{bg}Topics:{x}\n".c)
      @topics.each do |topic|
        output.push("- {bw}#{topic.title}{x}".c)
      end
      output.join("\n")
    end


    ##
    ## Return an array of topic titles
    ##
    ## @return     [Array] array of topic titles
    ##
    def list_topics
      @topics.map { |topic| topic.title }
    end

    ##
    ## Return a list of topic titles suitable for shell completion
    ##
    ## @return     [String] newline-separated list of topic titles
    ##
    def list_completions
      list_topics.join("\n")
    end

    ##
    ## Return a list of topics containing @directives,
    ## suitable for shell completion
    ##
    ## @return     [String] newline-separated list of topic
    ##             titles
    ##
    def list_runnable_completions
      output = []
      @topics.each do |topic|
        output.push(topic.title) if topic.tasks.count.positive?
      end
      output.join("\n")
    end

    ##
    ## Return a formatted list of topics containing
    ## @directives suitable for console output
    ##
    ## @return     [String] formatted list
    ##
    def list_runnable
      output = []
      output.push(%({bg}"Runnable" Topics:{x}\n).c)
      @topics.each do |topic|
        s_out = []

        topic.tasks.each do |task|
          s_out.push(task.to_list)
        end

        unless s_out.empty?
          output.push("- {bw}#{topic.title}{x}".c)
          output.push(s_out.join("\n"))
        end
      end
      output.join("\n")
    end

    ##
    ## Read the help file contents
    ##
    ## @param      file  [String] The filepath
    ##
    def read_file(file)
      read_help_file(file)
    end

    # Create a buildnotes skeleton
    def create_note
      trap('SIGINT') do
        Howzit.console.info "\nCancelled"
        exit!
      end
      default = !$stdout.isatty || Howzit.options[:default]
      # First make sure there isn't already a buildnotes file
      if note_file
        fname = "{by}#{note_file}{bw}".c
        unless default
          res = Prompt.yn("#{fname} exists and appears to be a build note, continue anyway?", default: false)
          unless res
            puts 'Canceled'
            Process.exit 0
          end
        end
      end

      title = File.basename(Dir.pwd)
      # prompt = TTY::Prompt.new
      if default
        input = title
      else
        # title = prompt.ask("{bw}Project name:{x}".c, default: title)
        printf "{bw}Project name {xg}[#{title}]{bw}: {x}".c
        input = $stdin.gets.chomp
        title = input unless input.empty?
      end
      summary = ''
      unless default
        printf '{bw}Project summary: {x}'.c
        input = $stdin.gets.chomp
        summary = input unless input.empty?
      end

      fname = 'buildnotes.md'
      unless default
        printf "{bw}Build notes filename (must begin with 'howzit' or 'build')\n{xg}[#{fname}]{bw}: {x}".c
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
        file = "{by}#{fname}".c
        res = Prompt.yn("Are you absolutely sure you want to overwrite #{file}", default: false)

        unless res
          puts 'Canceled'
          Process.exit 0
        end
      end

      File.open(fname, 'w') do |f|
        f.puts note
        puts "{by}Build notes for #{title} written to #{fname}".c
      end

      if File.exist?(fname) && !default
        res = Prompt.yn("{bg}Do you want to open {bw}#{file} {bg}for editing?{x}".c, default: false)

        edit_note if res
      end

      Process.exit 0
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

    ##
    ## Test if the filename matches the conditions to be a build note
    ##
    ## @param      filename  [String] The filename to test
    ##
    ## @return     [Boolean] true if filename passes test
    ##
    def build_note?(filename)
      return false if filename.downcase !~ /^(howzit[^.]*|build[^.]+)/

      return false if Howzit.config.should_ignore(filename)

      true
    end

    ##
    ## Glob current directory for valid build note filenames
    ##
    ## @return     [String] file path
    ##
    def glob_note
      filename = nil
      # Check for a build note file in the current folder. Filename must start
      # with "build" and have an extension of txt, md, or markdown.

      Dir.glob('*.{txt,md,markdown}').each do |f|
        if build_note?(f)
          filename = f
          break
        end
      end
      filename
    end

    ##
    ## Search for a valid build note, checking current
    ## directory, git top level directory, and parent
    ## directories
    ##
    ## @return     [String] filepath
    ##
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

    ##
    ## Search upstream directories for build notes
    ##
    ## @return     [Array] array of build note paths
    ##
    def read_upstream
      buildnotes = glob_upstream

      topics_dict = []
      buildnotes.each do |path|
        topics_dict.concat(read_help_file(path))
      end
      topics_dict
    end

    ##
    ## Test to ensure that any `required` metadata in a
    ## template is fulfilled by the build note
    ##
    ## @param      template  [String] The template to read
    ##                       from
    ##
    def ensure_requirements(template)
      t_leader = Util.read_file(template).split(/^#/)[0].strip
      if t_leader.length > 0
        t_meta = t_leader.get_metadata
        if t_meta.key?('required')
          required = t_meta['required'].strip.split(/\s*,\s*/)
          required.each do |req|
            unless @metadata.keys.include?(req.downcase)
              Howzit.console.error %({bRw}ERROR:{xbr} Missing required metadata key from template '{bw}#{File.basename(template, '.md')}{xr}'{x}).c
              Howzit.console.error %({br}Please define {by}#{req.downcase}{xr} in build notes{x}).c
              Process.exit 1
            end
          end
        end
      end
    end

    ##
    ## Read a list of topics from an included template
    ##
    ## @param      content  [String] The template contents
    ##
    def get_template_topics(content)
      leader = content.split(/^#/)[0].strip

      template_topics = []

      if leader.length > 0
        data = leader.get_metadata

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

    ##
    ## Import the contents of a filename as new topics
    ##
    ## @param      mtch  [MatchData] the filename match from
    ##                   the include directive
    ##
    def include_file(mtch)
      file = File.expand_path(mtch[1])

      return mtch[0] unless File.exist?(file)

      content = Util.read_file(file)
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

    ##
    ## Get the title of the build note (top level header)
    ##
    ## @param      truncate  [Integer] Truncate to width
    ##
    def note_title(truncate = 0)
      help = Util.read_file(note_file)
      title = help.match(/(?:^(\S.*?)(?=\n==)|^# ?(.*?)$)/)
      title = if title
                title[1].nil? ? title[2] : title[1]
              else
                note_file.sub(/(\.\w+)?$/, '')
              end

      title && truncate.positive? ? title.trunc(truncate) : title
    end

    # Read in the build notes file and output a hash of
    # "Title" => contents
    #
    # @param      path  [String] The build note path
    #
    # @return     [Array] array of Topics
    #
    def read_help_file(path = nil)
      topics = []

      filename = path.nil? ? note_file : path

      help = Util.read_file(filename)

      if help.nil? || help.empty?
        Howzit.console.error("{br}No content found in #{filename}{x}".c)
        Process.exit 1
      end

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

    ##
    ## Read build note and include upstream topics
    ##
    ## @param      path  [String] The build note path
    ##
    def read_help(path = nil)
      @topics = read_help_file(path)
      return unless path.nil? && Howzit.options[:include_upstream]

      upstream_topics = read_upstream

      upstream_topics.each do |topic|
        @topics.push(topic) unless find_topic(title.sub(/^.+:/, '')).count.positive?
      end

      if note_file && @topics.empty?
        Howzit.console.error("{br}Note file found but no topics detected in #{note_file}{x}".c)
        Process.exit 1
      end

    end

    ##
    ## Open build note in editor
    ##
    def edit_note
      editor = Howzit.options.fetch(:editor, ENV['EDITOR'])

      raise 'No editor defined' if editor.nil?

      raise "Invalid editor (#{editor})" unless Util.valid_command?(editor)

      if note_file.nil?
        res = Prompt.yn('No build notes file found, create one?', default: true)

        create_note if res
        edit_note
      else
        `#{editor} "#{note_file}"`
      end
    end

    ##
    ## Run or print a topic
    ##
    ## @param      topic   [Topic] The topic
    ## @param      run     [Boolean] execute directives if
    ##                     true
    ## @param      single  [Boolean] is being output as a
    ##                     single topic
    ##
    def process_topic(topic, run, single: false)
      new_topic = topic.dup

      # Handle variable replacement
      new_topic.content = new_topic.content.render_arguments

      output = if run
                 new_topic.run
               else
                 new_topic.print_out({ single: single })
               end
      output.nil? ? '' : output.join("\n")
    end

    ##
    ## Search and process the build note
    ##
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
            output.push(%({bR}ERROR:{xr} No topic match found for {bw}#{s}{x}\n).c)
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
        topic_matches.each { |topic_match| output.push(process_topic(topic_match, Howzit.options[:run], single: true)) }
      else
        # If there's no argument or no match found, output all
        topics.each { |k| output.push(process_topic(k, false, single: false)) }
      end
      Howzit.options[:paginate] = false if Howzit.options[:run]
      Util.show(output.join("\n").strip, Howzit.options)
    end
  end
end
