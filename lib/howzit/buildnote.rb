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
    def initialize(file: nil, meta: nil)
      file ||= note_file

      @topics = []
      create_note(prompt: true) if file.nil?

      content = Util.read_file(file)
      raise "{br}No content found in build note (#{file}){x}".c if content.nil? || content.empty?

      this_meta = content.split(/^#/)[0].strip.metadata

      @metadata = meta.nil? ? this_meta : meta.merge(this_meta)

      read_help(file)
    end

    ##
    ## Inspect
    ##
    ## @return     description
    ##
    def inspect
      "#<Howzit::BuildNote @topics=[#{@topics.count}]>"
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

      rx = term.to_rx

      @topics.filter do |topic|
        title = topic.title.downcase.sub(/ *\(.*?\) *$/, '')
        match = title =~ rx

        if !match && term =~ /[,:]/
          normalized = title.gsub(/\s*([,:])\s*/, '\1')
          match = normalized =~ rx
        end

        match
      end
    end

    ##
    ## Find a topic with an exact whole-word match
    ##
    ## @param      term  [String] The search term
    ##
    ## @return     [Array] Array of topics that exactly match the term
    ##
    def find_topic_exact(term = nil)
      return [] if term.nil?

      @topics.filter do |topic|
        title = topic.title.downcase.sub(/ *\(.*?\) *$/, '').strip
        # Split both the title and search term into words
        title_words = title.split
        search_words = term.split

        # Check if all search words match the title words exactly (case-insensitive)
        search_words.map(&:downcase) == title_words.map(&:downcase)
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
      @topics.map do |topic|
        title = topic.title
        title += "(#{topic.named_args.keys.join(', ')})" unless topic.named_args.empty?
        title
      end
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
        next unless topic.tasks.count.positive?

        title = topic.title
        title += "(#{topic.named_args.keys.join(', ')})" unless topic.named_args.empty?
        output.push(title)
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

        title = topic.title
        title += " {dy}({xy}#{topic.named_args.keys.join(', ')}{dy}){x}" unless topic.named_args.empty?

        output.push("- {g}#{title}{x}".c)
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
          Howzit.console.info('Cancelled')
          Process.exit 0
        end
      end

      File.open(file, 'w') do |f|
        f.puts note
        Howzit.console.info("{by}Template {bw}#{title}{by} written to {bw}#{file}{x}".c)
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

      # Template selection
      selected_templates = []
      template_metadata = {}
      unless default
        selected_templates, template_metadata = select_templates_for_note(title)
      end

      fname = 'buildnotes.md'
      unless default
        printf "{bw}Build notes filename (must begin with 'howzit' or 'build')\n{xg}[#{fname}]{bw}: {x}".c
        input = $stdin.gets.chomp
        fname = input unless input.empty?
      end

      # Build metadata section
      metadata_lines = []
      unless selected_templates.empty?
        metadata_lines << "template: #{selected_templates.join(',')}"
      end
      template_metadata.each do |key, value|
        metadata_lines << "#{key}: #{value}"
      end
      metadata_section = metadata_lines.empty? ? '' : "#{metadata_lines.join("\n")}\n\n"

      note = <<~EOBUILDNOTES
        #{metadata_section}# #{title}

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
          Howzit.console.info('Canceled')
          Process.exit 0
        end
      end

      File.open(fname, 'w') do |f|
        f.puts note
        Howzit.console.info("{by}Build notes for {bw}#{title}{by} written to {bw}#{fname}{x}".c)
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
    ## Select templates for a new build note
    ##
    ## @param      project_title  [String] The project title for prompts
    ##
    ## @return     [Array<Array, Hash>] Array of [selected_template_names, required_vars_hash]
    ##
    def select_templates_for_note(project_title)
      template_dir = Howzit.config.template_folder
      template_glob = File.join(template_dir, '*.md')
      template_files = Dir.glob(template_glob)

      return [[], {}] if template_files.empty?

      # Get basenames without extension for menu
      template_names = template_files.map { |f| File.basename(f, '.md') }.sort

      # Show multi-select menu
      selected = Prompt.choose_templates(template_names, prompt_text: 'Select templates to include')
      return [[], {}] if selected.empty?

      # Prompt for required variables from each template
      required_vars = {}
      selected.each do |template_name|
        template_path = File.join(template_dir, "#{template_name}.md")
        next unless File.exist?(template_path)

        vars = parse_template_required_vars(template_path)
        vars.each do |var|
          next if required_vars.key?(var)

          value = Prompt.get_line("{bw}[#{template_name}] requires {by}#{var}{x}".c)
          required_vars[var] = value unless value.empty?
        end
      end

      [selected, required_vars]
    end

    ##
    ## Parse a template file for required variables
    ##
    ## @param      template_path  [String] Path to the template file
    ##
    ## @return     [Array] Array of required variable names
    ##
    def parse_template_required_vars(template_path)
      content = File.read(template_path)

      # Look for required: in the metadata at the top of the file
      # Metadata is before the first # heading
      meta_section = content.split(/^#/)[0]
      return [] if meta_section.nil? || meta_section.strip.empty?

      # Find the required: line
      match = meta_section.match(/^required:\s*(.+)$/i)
      return [] unless match

      # Split by comma and strip whitespace
      match[1].split(',').map(&:strip).reject(&:empty?)
    end

    def topic_search_terms_from_cli
      args = Howzit.cli_args || []
      raw = args.join(' ').strip
      return [] if raw.empty?

      smart_split_topics(raw).map { |term| term.strip.downcase }.reject(&:empty?)
    end

    def smart_split_topics(raw)
      segments, separators = segments_and_separators_for(raw)
      return segments if separators.empty?

      combined = []
      current = segments.shift || ''

      separators.each_with_index do |separator, idx|
        next_segment = segments[idx] || ''
        if keep_separator_with_current?(current, separator, next_segment)
          current = "#{current}#{separator}#{next_segment}"
        else
          combined << current
          current = next_segment
        end
      end

      combined << current
      combined
    end

    def segments_and_separators_for(raw)
      segments = []
      separators = []
      current = String.new

      raw.each_char do |char|
        if char =~ /[,:]/
          segments << current
          separators << char
          current = String.new
        else
          current << char
        end
      end

      segments << current
      [segments, separators]
    end

    def keep_separator_with_current?(current, separator, next_segment)
      candidate = "#{current}#{separator}#{next_segment}"
      normalized_candidate = normalize_separator_string(candidate)
      return false if normalized_candidate.empty?

      @topics.any? do |topic|
        normalize_separator_string(topic.title).start_with?(normalized_candidate)
      end
    end

    def normalize_separator_string(string)
      return '' if string.nil?

      string.downcase.gsub(/\s+/, ' ').strip.gsub(/\s*([,:])\s*/, '\1')
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
    ## Test to ensure that any `required` metadata in a
    ## template is fulfilled by the build note
    ##
    ## @param      template  [String] The template to read
    ##                       from
    ##
    def ensure_requirements(template)
      t_leader = Util.read_file(template).split(/^#/)[0].strip
      return unless t_leader.length.positive?

      t_meta = t_leader.metadata

      return unless t_meta.key?('required')

      required = t_meta['required'].strip.split(/\s*,\s*/)
      required.each do |req|
        next if @metadata.keys.include?(req.downcase)

        Howzit.console.error %({bRw}ERROR:{xbr} Missing required metadata key from template '{bw}#{File.basename(
          template, '.md'
        )}{xr}'{x}).c
        Howzit.console.error %({br}Please define {by}#{req.downcase}{xr} in build notes{x}).c
        Process.exit 1
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
        subtopics = Regexp.last_match[1].split(/\s*\|\s*/).map { |t| t.gsub(/\*/, '.*?') }
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
      note = BuildNote.new(file: file, meta: @metadata)

      template_topics = subtopics.nil? ? note.topics : extract_subtopics(note, subtopics)
      template_topics.map do |topic|
        topic.parent = template
        topic.content = topic.content.render_template(@metadata)
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
      Dir.glob('*.{txt,md,markdown}').select(&:build_note?).sort[0]
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

      data = leader.metadata

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
        if path && path != note_file
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
      return unless Howzit.options[:include_upstream]

      unless Howzit.has_read_upstream
        upstream_topics = read_upstream

        upstream_topics.each do |topic|
          @topics.push(topic) unless find_topic(topic.title.sub(/^.+:/, '')).count.positive?
        end
        Howzit.has_read_upstream = true
      end

      return unless note_file && @topics.empty?

      Howzit.console.error("{br}Note file found but no topics detected in #{note_file}{x}".c)
      Process.exit 1
    end

    ##
    ## Open build note in editor
    ##
    def edit_note
      editor = Howzit.options.fetch(:editor, ENV['EDITOR'])

      editor = Howzit.config.update_editor if editor.nil?

      raise 'No editor defined' if editor.nil?

      raise "Invalid editor (#{editor})" unless Util.valid_command?(editor)

      create_note(prompt: true) if note_file.nil?
      exec %(#{editor} "#{note_file}")
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

      editor = Howzit.config.update_editor if editor.nil?

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
      new_topic = topic.is_a?(String) ? find_topic(topic)[0] : topic.dup

      output = if run
                 new_topic.run
               else
                 new_topic.print_out({ single: single })
               end

      output.nil? ? '' : output.join("\n\n")
    end

    ##
    ## Search and process the build note
    ##
    def process
      output = []
      if Howzit.options[:run]
        Howzit.run_log = []
        Howzit.multi_topic_run = false
      end

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

      # Handle grep and choose modes (batch all results)
      if Howzit.options[:grep]
        topic_matches = []
        matches = grep(Howzit.options[:grep])
        case Howzit.options[:multiple_matches]
        when :all
          topic_matches.concat(matches.sort_by(&:title))
        else
          topic_matches.concat(Prompt.choose(matches.map(&:title), height: :max, query: Howzit.options[:grep]))
        end
        process_topic_matches(topic_matches, output)
      elsif Howzit.options[:choose]
        topic_matches = []
        titles = Prompt.choose(list_topics, height: :max)
        titles.each { |title| topic_matches.push(find_topic(title)[0]) }
        process_topic_matches(topic_matches, output)
      elsif !Howzit.cli_args.empty?
        # Collect all topic matches first (showing menus as needed)
        search = topic_search_terms_from_cli
        topic_matches = collect_topic_matches(search, output)
        process_topic_matches(topic_matches, output)
      else
        # No arguments - show all topics
        if Howzit.options[:run]
          Howzit.run_log = []
          Howzit.multi_topic_run = topics.length > 1
        end
        topics.each { |k| output.push(process_topic(k, false, single: false)) }
        finalize_output(output)
      end
    end

    ##
    ## Collect all topic matches from search terms, showing menus as needed
    ## but not displaying/running until all selections are made
    ##
    ## @param      search_terms  [Array] Array of search term strings
    ## @param      output        [Array] Output array for error messages
    ##
    ## @return     [Array] Array of all matched topics
    ##
    def collect_topic_matches(search_terms, output)
      all_matches = []

      search_terms.each do |s|
        # First check for exact whole-word matches
        exact_matches = find_topic_exact(s)

        topic_matches = if !exact_matches.empty?
                          exact_matches
                        else
                          resolve_fuzzy_matches(s, output)
                        end

        if topic_matches.empty?
          output.push(%({bR}ERROR:{xr} No topic match found for {bw}#{s}{x}\n).c)
        else
          all_matches.concat(topic_matches)
        end
      end

      all_matches
    end

    ##
    ## Resolve fuzzy matches for a search term
    ##
    ## @param      search_term  [String] The search term
    ## @param      output       [Array] Output array for errors
    ##
    ## @return     [Array] Array of matched topics
    ##
    def resolve_fuzzy_matches(search_term, output)
      matches = find_topic(search_term)

      return [] if matches.empty?

      case Howzit.options[:multiple_matches]
      when :first
        [matches[0]]
      when :best
        [matches.sort_by { |a| [a.title.comp_distance(search_term), a.title.length] }.first]
      when :all
        matches
      else
        titles = matches.map(&:title)
        res = Prompt.choose(titles, query: search_term)
        old_matching = Howzit.options[:matching]
        Howzit.options[:matching] = 'exact'
        selected = res.flat_map { |title| find_topic(title) }
        Howzit.options[:matching] = old_matching
        selected
      end
    end

    ##
    ## Process collected topic matches and display output
    ##
    ## @param      topic_matches  [Array] Array of matched topics
    ## @param      output         [Array] Output array
    ##
    def process_topic_matches(topic_matches, output)
      if topic_matches.empty? && !Howzit.options[:show_all_on_error]
        Util.show(output.join("\n"), { color: true, highlight: false, paginate: false, wrap: 0 })
        Process.exit 1
      end

      if Howzit.options[:run]
        Howzit.run_log = []
        Howzit.multi_topic_run = topic_matches.length > 1
      end

      if !topic_matches.empty?
        topic_matches.map! { |topic| topic.is_a?(String) ? find_topic(topic)[0] : topic }
        topic_matches.each { |topic_match| output.push(process_topic(topic_match, Howzit.options[:run], single: true)) }
      else
        topics.each { |k| output.push(process_topic(k, false, single: false)) }
      end

      finalize_output(output)
    end

    ##
    ## Finalize and display output with run summary if applicable
    ##
    ## @param      output  [Array] Output array
    ##
    def finalize_output(output)
      if Howzit.options[:run]
        Howzit.options[:paginate] = false
        summary = Howzit::RunReport.format
        output.push(summary) unless summary.empty?
      end
      Util.show(output.join("\n").strip, Howzit.options)
    end
  end
end
