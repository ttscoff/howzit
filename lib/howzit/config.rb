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
      return false unless File.exist?(ignore_file)

      @ignore_patterns ||= YAML.load(Util.read_file(ignore_file))

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
