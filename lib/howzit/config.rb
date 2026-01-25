# frozen_string_literal: true

module Howzit
  # Config Class
  class Config
    attr_reader :options

    # Configuration defaults
    DEFAULTS = {
      color: true,
      config_editor: ENV['EDITOR'] || nil,
      editor: ENV['EDITOR'] || nil,
      header_format: 'border',
      highlight: true,
      highlighter: 'auto',
      include_upstream: false,
      stack: false,
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

    DEFAULT_COLORS = [
      [:black,              30],
      [:red,                31],
      [:green,              32],
      [:yellow,             33],
      [:blue,               34],
      [:magenta,            35],
      [:purple,             35],
      [:cyan,               36],
      [:white,              37],
      [:bgblack,            40],
      [:bgred,              41],
      [:bggreen,            42],
      [:bgyellow,           43],
      [:bgblue,             44],
      [:bgmagenta,          45],
      [:bgpurple,           45],
      [:bgcyan,             46],
      [:bgwhite,            47],
      [:boldblack,          90],
      [:boldred,            91],
      [:boldgreen,          92],
      [:boldyellow,         93],
      [:boldblue,           94],
      [:boldmagenta,        95],
      [:boldpurple,         95],
      [:boldcyan,           96],
      [:boldwhite,          97],
      [:boldbgblack,       100],
      [:boldbgred,         101],
      [:boldbggreen,       102],
      [:boldbgyellow,      103],
      [:boldbgblue,        104],
      [:boldbgmagenta,     105],
      [:boldbgpurple,      105],
      [:boldbgcyan,        106],
      [:boldbgwhite,       107]
    ].to_h.deep_freeze

    ##
    ## Initialize a config object
    ##
    def initialize
      @initializing = true
      begin
        load_options
      ensure
        @initializing = false
      end
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
    ## Write a theme to a file
    ##
    ## @param      config  The configuration
    ##
    def write_theme(config)
      File.open(theme_file, 'w') { |f| f.puts config.to_yaml }
    end

    ##
    ## Test if a file should be ignored based on YAML file
    ##
    ## @param      filename  The filename to test
    ##
    def should_ignore(filename)
      # Prevent recursion: if we're already loading ignore patterns, skip the check
      return false if defined?(@loading_ignore_patterns) && @loading_ignore_patterns

      # Don't check the ignore file itself - do this before any file operations
      begin
        ignore_file_path = ignore_file
        return false if filename == ignore_file_path || File.expand_path(filename) == File.expand_path(ignore_file_path)
      rescue StandardError
        # If ignore_file access fails, skip the check to prevent recursion
        return false
      end

      return false unless File.exist?(ignore_file_path)

      begin
        @loading_ignore_patterns = true
        @ignore_patterns ||= YAML.load(Util.read_file(ignore_file_path))
      ensure
        @loading_ignore_patterns = false
      end

      return false unless @ignore_patterns.is_a?(Array)

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
      edit_config
    end

    ## Update editor config
    def update_editor
      begin
        puts 'No $EDITOR defined, no value in config'
      rescue Errno::EPIPE
        # Pipe closed, ignore
      end
      editor = Prompt.read_editor
      if editor.nil?
        begin
          puts 'Cancelled, no editor stored.'
        rescue Errno::EPIPE
          # Pipe closed, ignore
        end
        Process.exit 1
      end
      update_config_option({ config_editor: editor, editor: editor })
      begin
        puts "Default editor set to #{editor}, modify in config file"
      rescue Errno::EPIPE
        # Pipe closed, ignore
      end
      editor
    end

    ##
    ## Update a config option and resave config file
    ##
    ## @param      options    [Hash] key value pairs
    ##
    def update_config_option(options)
      options.each do |key, value|
        Howzit.options[key] = value
      end
      write_config(Howzit.options)
    end

    private

    ##
    ## Load command line options
    ##
    ## @return     [Hash] options with command line flags merged in
    ##
    def load_options
      Color.coloring = $stdout.isatty
      flags = {
        ask: false,
        choose: false,
        default: false,
        for_topic: nil,
        force: false,
        grep: nil,
        list_runnable: false,
        list_runnable_titles: false,
        list_topic_titles: false,
        list_topics: false,
        quiet: false,
        run: false,
        title_only: false,
        verbose: false,
        yes: false
      }

      config = load_config
      load_theme
      @options = flags.merge(config)

      # Check for HOWZIT_LOG_LEVEL environment variable
      return unless ENV['HOWZIT_LOG_LEVEL']

      level_str = ENV['HOWZIT_LOG_LEVEL'].downcase
      level_map = {
        'debug' => 0,
        'info' => 1,
        'warn' => 2,
        'warning' => 2,
        'error' => 3
      }
      @options[:log_level] = level_map[level_str] || level_str.to_i
    end

    ##
    ## Get the config directory
    ##
    ## @return     [String] path to config directory
    ##
    def config_dir
      File.expand_path(CONFIG_DIR)
    end

    ##
    ## Get the config file
    ##
    ## @return     [String] path to config file
    ##
    def config_file
      File.join(config_dir, CONFIG_FILE)
    end

    ##
    ## Get the theme file
    ##
    ## @return     [String] path to config file
    ##
    def theme_file
      File.join(config_dir, COLOR_FILE)
    end

    ##
    ## Get the ignore config file
    ##
    ## @return     [String] path to ignore config file
    ##
    def ignore_file
      File.join(config_dir, IGNORE_FILE)
    end

    ##
    ## Create a new config file (and directory if needed)
    ##
    ## @param      default     [Hash] default configuration to write
    ##
    def create_config(default)
      # If a legacy ~/.local/share/howzit directory exists, offer to migrate it
      # into the new config root before creating any new files to avoid confusion
      # about where Howzit stores its configuration.
      # Use early_init=true since we're called during config initialization and can't access Howzit.options yet
      if defined?(Howzit::ScriptSupport) && File.directory?(File.expand_path(Howzit::ScriptSupport::LEGACY_SUPPORT_DIR))
        Howzit::ScriptSupport.migrate_legacy_support(early_init: true)
      end

      unless File.directory?(config_dir)
        Howzit::ConsoleLogger.new(1).info "Creating config directory at #{config_dir}"
        FileUtils.mkdir_p(config_dir)
      end

      unless File.exist?(config_file)
        Howzit::ConsoleLogger.new(1).info "Writing fresh config file to #{config_file}"
        write_config(default)
      end
      config_file
    end

    ##
    ## Create a new theme file (and directory if needed)
    ##
    ## @param      default     [Hash] default configuration to write
    ##
    def create_theme(default)
      unless File.directory?(config_dir)
        Howzit::ConsoleLogger.new(1).info "Creating theme directory at #{config_dir}"
        FileUtils.mkdir_p(config_dir)
      end

      unless File.exist?(theme_file)
        Howzit::ConsoleLogger.new(1).info "Writing fresh theme file to #{theme_file}"
        write_theme(default)
      end
      theme_file
    end

    ##
    ## Load the config file
    ##
    ## @return     [Hash] configuration object
    ##
    def load_config
      file = create_config(DEFAULTS)
      config = YAML.load(Util.read_file(file))
      newconfig = config ? DEFAULTS.merge(config) : DEFAULTS
      write_config(newconfig)
      newconfig.dup
    end

    ##
    ## Load the theme file
    ##
    ## @return     [Hash] configuration object
    ##
    def load_theme
      file = create_theme(DEFAULT_COLORS)
      config = YAML.load(Util.read_file(file))
      newconfig = config ? DEFAULT_COLORS.merge(config) : DEFAULT_COLORS
      write_theme(newconfig)
      newconfig.dup
    end

    ##
    ## Open the config in an editor
    ##
    def edit_config
      editor = Howzit.options.fetch(:config_editor, ENV['EDITOR'])

      editor = update_editor if editor.nil?

      raise 'No config_editor defined' if editor.nil?

      # raise "Invalid editor (#{editor})" unless Util.valid_command?(editor)

      load_config
      if Util.valid_command?(editor.split(/ /).first)
        exec %(#{editor} "#{config_file}")
      else
        `open -a "#{editor}" "#{config_file}"`
      end
    end
  end
end
