module Howzit
  # Config Class
  class Config
    attr_reader :options

    DEFAULTS = {
      color: true,
      config_editor: ENV['EDITOR'] || nil,
      editor: ENV['EDITOR'] || nil,
      header_format: 'border',
      highlight: true,
      highlighter: 'auto',
      include_upstream: false,
      log_level: 1, # 0: debug, 1: info, 2: warn, 3: error
      matching: 'partial', # exact, partial, fuzzy, beginswith
      multiple_matches: 'choose',
      output_title: false,
      pager: 'auto',
      paginate: true,
      show_all_code: false,
      show_all_on_error: false,
      wrap: 0
    }.deep_freeze

    ##
    ## Initialize a config object
    ##
    def initialize
      load_options
    end

    ##
    ## Write a config to a file
    ##
    ## @param      config  The configuration
    ##
    def write_config(config)
      File.open(config_file, 'w') { |f| f.puts config.to_yaml }
    end

    ##
    ## Test if a file should be ignored based on YAML file
    ##
    ## @param      filename  The filename to test
    ##
    def should_ignore(filename)
      return false unless File.exist?(ignore_file)

      @ignore_patterns ||= YAML.safe_load(IO.read(ignore_file))

      ignore = false

      @ignore_patterns.each do |pat|
        if filename =~ /#{pat}/
          ignore = true
          break
        end
      end

      ignore
    end

    ##
    ## Find the template folder
    ##
    ## @return     [String] path to template folder
    ##
    def template_folder
      File.join(config_dir, 'templates')
    end

    ##
    ## Initiate the editor for the config
    ##
    def editor
      edit_config(DEFAULTS)
    end

    private

    def load_options
      Color.coloring = $stdout.isatty
      flags = {
        choose: false,
        default: false,
        grep: nil,
        list_runnable: false,
        list_runnable_titles: false,
        list_topic_titles: false,
        list_topics: false,
        quiet: false,
        run: false,
        title_only: false,
        verbose: false
      }

      config = load_config
      @options = flags.merge(config)
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

    def create_config(d)
      unless File.directory?(config_dir)
        Howzit::ConsoleLogger.new(1).info "Creating config directory at #{config_dir}"
        FileUtils.mkdir_p(config_dir)
      end

      unless File.exist?(config_file)
        Howzit::ConsoleLogger.new(1).info "Writing fresh config file to #{config_file}"
        write_config(d)
      end
      config_file
    end

    def load_config
      file = create_config(DEFAULTS)
      config = YAML.load(IO.read(file))
      newconfig = config ? DEFAULTS.merge(config) : DEFAULTS
      write_config(newconfig)
      newconfig.dup
    end

    def edit_config(d)
      editor = Howzit.options.fetch(:config_editor, ENV['EDITOR'])

      raise 'No config_editor defined' if editor.nil?

      # raise "Invalid editor (#{editor})" unless Util.valid_command?(editor)

      load_config
      if Util.valid_command?(editor.split(/ /).first)
        system %(#{editor} "#{config_file}")
      else
        `open -a "#{editor}" "#{config_file}"`
      end
    end
  end
end
