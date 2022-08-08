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
    ##
    def initialize(file: nil)
      file ||= note_file
      @topics = []
      create_note(prompt: true) if file.nil?

      content = Util.read_file(file)
      raise "{br}No content found in build note (#{file}){x}".c if content.nil? || content.empty?

      @metadata = content.split(/^#/)[0].strip.get_metadata

      read_help(file)
    end

    ##
    ## Inspect
    ##
    ## @return     description
    ##
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
    ## Public method to open a template in the editor
    ##
    ## @param      template  [String] The template title
    ##
    def edit_template(template)
      file = template.sub(/(\.md)?$/i, '.md')
      file = File.join(Howzit.config.template_folder, file)
      edit_template_file(file)
    end

    ##
    ## Find a topic based on a fuzzy match
    ##
    ## @param      term  [String] The search term
    ##
    def find_topic(term = nil)
      return @topics if term.nil?

      @topics.filter do |topic|
        rx = term.to_rx
        topic.title.downcase =~ rx
      end
    end

    ##
    ## Copy a link to the main build note file to clipboard (macOS only)
    ##
    def hook
      title = Util.read_file(note_file).note_title(note_file, 20)
      title = "#{title} project notes"
      url = "[#{title}](file://#{note_file})"
      Util.os_copy(url)
      Howzit.console.info('Link copied to clipboard.')
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
    ## directives suitable for console output
    ##
    ## @return     [String] formatted list
    ##
    def list_runnable
      output = []
      output.push(%({bg}"Runnable" Topics:{x}\n).c)

      find_topic(Howzit.options[:for_topic]).each do |topic|
        s_out = []

        topic.tasks.each { |task| s_out.push(task.to_list) }

        next if s_out.empty?

        output.push("- {bw}#{topic.title}{x}".c)
        output.push(s_out.join("\n"))
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

    ##
    ## Create a template file
    ##
    ## @param      file    [String] file path
    ## @param      prompt  [Boolean] confirm file creation?
    ##
    def create_template_file(file, prompt: false)
      trap('SIGINT') do
        Howzit.console.info "\nCancelled"
        exit!
      end

      default = !$stdout.isatty || Howzit.options[:default]

      if prompt && !default && !File.exist?(file)
        res = Prompt.yn("{bg}Template {bw}#{File.basename(file)}{bg} not found, create it?{x}".c, default: true)
        Process.exit 0 unless res
      end

      title = File.basename(file, '.md')

      note = <<~EOBUILDNOTES
        # #{title}

        ## Template Topic

      EOBUILDNOTES

      if File.exist?(file) && !default
        file = "{by}#{file}".c
        unless Prompt.yn("Are you sure you want to overwrite #{file}", default: false)
          puts 'Cancelled'
          Process.exit 0
        end
      end

      File.open(file, 'w') do |f|
        f.puts note
        puts "{by}Template {bw}#{title}{by} written to {bw}#{file}{x}".c
      end

      if File.exist?(file) && !default && Prompt.yn("{bg}Do you want to open {bw}#{file} {bg}for editing?{x}".c,
                                                     default: false)
        edit_template_file(file)
      end

      Process.exit 0
    end

    # Create a buildnotes skeleton
    def create_note(prompt: false)
      trap('SIGINT') do
        Howzit.console.info "\nCancelled"
        exit!
      end

      default = !$stdout.isatty || Howzit.options[:default]

      if prompt && !default
        res = Prompt.yn('No build notes file found, create one?', default: true)
        Process.exit 0 unless res
      end

      # First make sure there isn't already a buildnotes file
      if note_file
        fname = "{by}#{note_file}{bw}".c
        unless default
          res = Prompt.yn("#{fname} exists and appears to be a build note, continue anyway?", default: false)
          Process.exit 0 unless res
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
        unless Prompt.yn("Are you absolutely sure you want to overwrite #{file}", default: false)
          puts 'Canceled'
          Process.exit 0
        end
      end

      File.open(fname, 'w') do |f|
        f.puts note
        puts "{by}Build notes for {bw}#{title}{by} written to {bw}#{fname}{x}".c
      end

      if File.exist?(fname) && !default && Prompt.yn("{bg}Do you want to open {bw}#{fname} {bg}for editing?{x}".c,
                                                     default: false)
        edit_note
      end

      Process.exit 0
    end

    ##
    ## Accessor method for note_file (path to located build note)
    ##
    ## @return     [String] path
    ##
    def note_file
      @note_file ||= find_note_file
    end

    private

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
    ## Test a template string for bracketed subtopics
    ##
    ## @param      template  [String] The template name
    ##
    ## @return     [Array] [[String] updated template name, [Array]
    ##             subtopic titles]
    ##
    def detect_subtopics(template)
      subtopics = nil

      if template =~ /\[(.*?)\]$/
        subtopics = Regexp.last_match[1].split(/\s*\|\s*/).map { |t| t.gsub(/\*/, '.*?')}
        template.sub!(/\[.*?\]$/, '').strip
      end

      [template, subtopics]
    end

    ##
    ## Enumerate templates and read their associated files
    ## into topics
    ##
    ## @param      templates  [Array] The templates to read
    ##
    ## @return     [Array] template topics
    ##
    def gather_templates(templates)
      template_topics = []

      templates.each do |template|
        template, subtopics = detect_subtopics(template)

        file = template.sub(/(\.md)?$/i, '.md')
        file = File.join(Howzit.config.template_folder, file)

        next unless File.exist?(file)

        ensure_requirements(file)

        template_topics.concat(read_template(template, file, subtopics))
      end

      template_topics
    end

    ##
    ## Filter topics based on subtopic titles
    ##
    ## @param      note       [BuildNote] The note
    ## @param      subtopics  [Array] The subtopics to
    ##                        extract
    ##
    ## @return     [Array] extracted subtopics
    ##
    def extract_subtopics(note, subtopics)
      template_topics = []

      subtopics.each do |subtopic|
        note.topics.each { |topic| template_topics.push(topic) if topic.title =~ /^(.*?:)?#{subtopic}$/i }
      end

      template_topics
    end

    ##
    ## Read a template file
    ##
    ## @param      template   [String] The template title
    ## @param      file       [String] The file path
    ## @param      subtopics  [Array] The subtopics to
    ##                        extract, nil to return all
    ##
    ## @return     [Array] extracted topics
    ##
    def read_template(template, file, subtopics = nil)
      note = BuildNote.new(file: file)

      template_topics = subtopics.nil? ? note.topics : extract_subtopics(note, subtopics)
      template_topics.map do |topic|
        topic.parent = template
        topic
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

    ##
    ## Glob current directory for valid build note filenames
    ## (must start with "build" or "howzit" and have
    ## extension of "txt", "md", or "markdown")
    ##
    ## @return     [String] file path
    ##
    def glob_note
      Dir.glob('*.{txt,md,markdown}').select(&:build_note?)[0]
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
    ## Read a list of topics from an included template
    ##
    ## @param      content  [String] The template contents
    ##
    def get_template_topics(content)
      leader = content.split(/^#/)[0].strip

      template_topics = []

      return template_topics if leader.empty?

      data = leader.get_metadata

      if data.key?('template')
        templates = data['template'].strip.split(/\s*,\s*/)

        template_topics.concat(gather_templates(templates))
      end

      template_topics
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

      @title = help.note_title(filename)

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

      create_note(prompt: true) if note_file.nil?
      `#{editor} "#{note_file}"`
    end

    ##
    ## Public method to create a new template
    ##
    ## @param      template  [String] The template name
    ##
    def create_template(template)
      file = template.sub(/(\.md)?$/i, '.md')
      file = File.join(Howzit.config.template_folder, file)
      create_template_file(file, prompt: false)
    end

    ##
    ## Open template in editor
    ##
    def edit_template_file(file)
      editor = Howzit.options.fetch(:editor, ENV['EDITOR'])

      raise 'No editor defined' if editor.nil?

      raise "Invalid editor (#{editor})" unless Util.valid_command?(editor)

      create_template_file(file, prompt: true) unless File.exist?(file)
      `#{editor} "#{file}"`
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

        create_note(prompt: true)
      end

      if Howzit.options[:title_only]
        out = Util.read_file(note_file).note_title(note_file, 20)
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
        matches = grep(Howzit.options[:grep])
        case Howzit.options[:multiple_matches]
        when :all
          topic_matches.concat(matches.sort_by(&:title))
        else
          topic_matches.concat(Prompt.choose(matches.map(&:title), height: :max))
        end
      elsif Howzit.options[:choose]
        titles = Prompt.choose(list_topics, height: :max)
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
