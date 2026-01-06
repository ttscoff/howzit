# frozen_string_literal: true

require 'fileutils'
require 'shellwords'

module Howzit
  # Script Support module
  # Handles helper script installation and injection for run blocks
  # rubocop:disable Metrics/ModuleLength
  module ScriptSupport
    # Prefer XDG_CONFIG_HOME/howzit/support if set, otherwise ~/.config/howzit/support.
    # For backwards compatibility, we detect an existing ~/.local/share/howzit directory
    # and can optionally migrate it to the new location.
    LEGACY_SUPPORT_DIR = File.join(Dir.home, '.local', 'share', 'howzit')
    SUPPORT_DIR = if ENV['XDG_CONFIG_HOME'] && !ENV['XDG_CONFIG_HOME'].empty?
                    File.join(ENV['XDG_CONFIG_HOME'], 'howzit', 'support')
                  else
                    File.join(Dir.home, '.config', 'howzit', 'support')
                  end

    class << self
      ##
      ## Get the support directory path
      ##
      ## @return     [String] expanded path to support directory
      ##
      def support_dir
        File.expand_path(SUPPORT_DIR)
      end

      ##
      ## Ensure support directory exists and is populated
      ##
      def ensure_support_dir
        dir = support_dir
        legacy_dir = File.expand_path(LEGACY_SUPPORT_DIR)
        new_root  = File.expand_path(File.join(SUPPORT_DIR, '..'))

        # If legacy files exist, always offer to migrate them before proceeding.
        # Use early_init=false here since config is already loaded by the time we reach this point
        migrate_legacy_support(early_init: false) if File.directory?(legacy_dir)

        FileUtils.mkdir_p(dir) unless File.directory?(dir)
        install_helper_scripts
        dir
      end

      ##
      ## Simple Y/N prompt that doesn't depend on Howzit.options (for use during early config initialization)
      ##
      def simple_yn_prompt(prompt, default: true)
        return default unless $stdout.isatty

        tty_state = `stty -g`
        yn = default ? '[Y/n]' : '[y/N]'
        $stdout.syswrite "\e[1;37m#{prompt} #{yn}\e[1;37m? \e[0m"
        system 'stty raw -echo cbreak isig'
        res = $stdin.sysread 1
        res.chomp!
        puts
        system 'stty cooked'
        system "stty #{tty_state}"
        res.empty? ? default : res =~ /y/i
      end

      ##
      ## Migrate legacy ~/.local/share/howzit directory into the new config root,
      ## merging contents and removing the legacy directory when complete.
      ##
      ## @param      early_init  [Boolean] If true, use simple prompt that doesn't access Howzit.options
      ##
      def migrate_legacy_support(early_init: false)
        legacy_dir = File.expand_path(LEGACY_SUPPORT_DIR)
        new_root  = File.expand_path(File.join(SUPPORT_DIR, '..'))

        unless File.directory?(legacy_dir)
          if early_init
            return
          else
            Howzit.console.info "No legacy Howzit directory found at #{legacy_dir}; nothing to migrate."
            return
          end
        end

        prompt = "Migrate Howzit files from #{legacy_dir} to #{new_root}? This will overwrite files in the new location with legacy versions, " \
                 'add new files, and leave any extra files in the new location in place.'

        if early_init
          unless simple_yn_prompt(prompt, default: true)
            $stderr.puts 'Migration cancelled; no changes made.'
            return
          end
        else
          unless Prompt.yn(prompt, default: true)
            Howzit.console.info 'Migration cancelled; no changes made.'
            return
          end
        end

        FileUtils.mkdir_p(new_root) unless File.directory?(new_root)

        # Merge legacy into new_root:
        # - overwrite files in new_root with versions from legacy
        # - add files that do not yet exist
        # - leave files that exist only in new_root untouched
        Dir.children(legacy_dir).each do |entry|
          src = File.join(legacy_dir, entry)
          dest = File.join(new_root, entry)

          if File.directory?(src)
            FileUtils.mkdir_p(dest)
            FileUtils.cp_r(File.join(src, '.'), dest)
          else
            FileUtils.cp(src, dest)
          end
        end

        FileUtils.rm_rf(legacy_dir)
        if early_init
          $stderr.puts "Migrated Howzit files from #{legacy_dir} to #{new_root}."
        else
          Howzit.console.info "Migrated Howzit files from #{legacy_dir} to #{new_root}."
        end
      end

      ##
      ## Detect interpreter from hashbang line
      ##
      ## @param      script_content  [String] The script content
      ##
      ## @return     [Symbol, nil] Language identifier (:bash, :zsh, :fish, :ruby, :python, etc.)
      ##
      def detect_interpreter(script_content)
        first_line = script_content.lines.first&.strip
        return nil unless first_line&.start_with?('#!')

        shebang = first_line.sub(/^#!/, '').strip

        case shebang
        when %r{/bin/bash}, %r{/usr/bin/env bash}
          :bash
        when %r{/bin/zsh}, %r{/usr/bin/env zsh}
          :zsh
        when %r{/bin/fish}, %r{/usr/bin/env fish}
          :fish
        when %r{/usr/bin/env ruby}, %r{/usr/bin/ruby}, %r{/usr/local/bin/ruby}
          :ruby
        when %r{/usr/bin/env python3?}, %r{/usr/bin/python3?}, %r{/usr/local/bin/python3?}
          :python
        when %r{/usr/bin/env perl}, %r{/usr/bin/perl}
          :perl
        when %r{/usr/bin/env node}, %r{/usr/bin/node}
          :node
        end
      end

      ##
      ## Get the injection line for a given interpreter
      ##
      ## @param      interpreter  [Symbol] The interpreter type
      ##
      ## @return     [String, nil] The injection line to add
      ##
      def injection_line_for(interpreter)
        support_path = support_dir
        case interpreter
        when :bash, :zsh
          "source \"#{support_path}/howzit.sh\""
        when :fish
          "source \"#{support_path}/howzit.fish\""
        when :ruby
          "require '#{support_path}/howzit.rb'"
        when :python
          "import sys\nsys.path.insert(0, '#{support_path}')\nimport howzit"
        when :perl
          "require '#{support_path}/howzit.pl'"
        when :node
          "require('#{support_path}/howzit.js')"
        end
      end

      ##
      ## Inject helper script loading into script content
      ##
      ## @param      script_content  [String] The original script content
      ##
      ## @return     [Array] [modified_content, interpreter] Script content with injection added and interpreter
      ##
      def inject_helper(script_content)
        interpreter = detect_interpreter(script_content)
        return [script_content, nil] unless interpreter

        injection = injection_line_for(interpreter)
        return [script_content, interpreter] unless injection

        lines = script_content.lines
        injection_lines = injection.split("\n").map { |l| "#{l}\n" }
        # Find the hashbang line
        if lines.first&.strip&.start_with?('#!')
          # Insert after hashbang
          injection_lines.each_with_index do |line, idx|
            lines.insert(1 + idx, line)
          end
        else
          # No hashbang, prepend
          lines = injection_lines + lines
        end

        [lines.join, interpreter]
      end

      ##
      ## Get the command to execute a script based on interpreter
      ##
      ## @param      script_path   [String] Path to the script file
      ## @param      interpreter   [Symbol, nil] The interpreter type
      ##
      ## @return     [String] Command to execute the script
      ##
      def execution_command_for(script_path, interpreter)
        cmd = case interpreter
              when :bash
                "/bin/bash #{Shellwords.escape(script_path)}"
              when :zsh
                "/bin/zsh #{Shellwords.escape(script_path)}"
              when :fish
                "/usr/bin/env fish #{Shellwords.escape(script_path)}"
              when :ruby
                "/usr/bin/env ruby #{Shellwords.escape(script_path)}"
              when :python
                "/usr/bin/env python3 #{Shellwords.escape(script_path)}"
              when :perl
                "/usr/bin/env perl #{Shellwords.escape(script_path)}"
              when :node
                "/usr/bin/env node #{Shellwords.escape(script_path)}"
              end
        # Fallback to direct execution if interpreter not recognized
        cmd || script_path
      end

      ##
      ## Install all helper scripts
      ##
      def install_helper_scripts
        dir = support_dir
        FileUtils.mkdir_p(dir)

        install_bash_helper(dir)
        install_fish_helper(dir)
        install_ruby_helper(dir)
        install_python_helper(dir)
        install_perl_helper(dir)
        install_node_helper(dir)
      end

      private

      ##
      ## Install bash/zsh helper script
      ##
      def install_bash_helper(dir)
        file = File.join(dir, 'howzit.sh')
        return if File.exist?(file) && !file_stale?(file)

        content = <<~BASH
          #!/bin/bash
          # Howzit helper functions for bash/zsh

          # Log functions
          log() {
            local level="$1"
            shift
            local message="$*"
            if [ -n "$HOWZIT_COMM_FILE" ]; then
              echo "LOG:$level:$message" >> "$HOWZIT_COMM_FILE"
            fi
          }

          log_info() { log info "$@"; }
          log_warn() { log warn "$@"; }
          log_error() { log error "$@"; }
          log_debug() { log debug "$@"; }

          # Set variable function
          set_var() {
            local var_name="$1"
            local var_value="$2"
            if [ -n "$HOWZIT_COMM_FILE" ]; then
              echo "VAR:$var_name=$var_value" >> "$HOWZIT_COMM_FILE"
            fi
          }
        BASH

        File.write(file, content)
        File.chmod(0o644, file)
      end

      ##
      ## Install fish helper script
      ##
      def install_fish_helper(dir)
        file = File.join(dir, 'howzit.fish')
        return if File.exist?(file) && !file_stale?(file)

        content = <<~FISH
          #!/usr/bin/env fish
          # Howzit helper functions for fish

          function log -d "Log a message at the specified level"
            set level $argv[1]
            set -e argv[1]
            set message (string join " " $argv)
            if test -n "$HOWZIT_COMM_FILE"
              echo "LOG:$level:$message" >> "$HOWZIT_COMM_FILE"
            end
          end

          function log_info -d "Log an info message"
            log info $argv
          end

          function log_warn -d "Log a warning message"
            log warn $argv
          end

          function log_error -d "Log an error message"
            log error $argv
          end

          function log_debug -d "Log a debug message"
            log debug $argv
          end

          function set_var -d "Set a variable for howzit"
            set var_name $argv[1]
            set var_value $argv[2]
            if test -n "$HOWZIT_COMM_FILE"
              echo "VAR:$var_name=$var_value" >> "$HOWZIT_COMM_FILE"
            end
          end
        FISH

        File.write(file, content)
        File.chmod(0o644, file)
      end

      ##
      ## Install Ruby helper script
      ##
      def install_ruby_helper(dir)
        file = File.join(dir, 'howzit.rb')
        return if File.exist?(file) && !file_stale?(file)

        content = <<~'RUBY'
          # frozen_string_literal: true

          # Howzit helper module for Ruby
          module Howzit
            class << self
              # Log methods
              def logger
                @logger ||= Logger.new
              end

              class Logger
                def info(message)
                  log(:info, message)
                end

                def warn(message)
                  log(:warn, message)
                end

                def error(message)
                  log(:error, message)
                end

                def debug(message)
                  log(:debug, message)
                end

                private

                def log(level, message)
                  comm_file = ENV['HOWZIT_COMM_FILE']
                  return unless comm_file

                  File.open(comm_file, 'a') do |f|
                    f.puts "LOG:#{level}:#{message}"
                  end
                end
              end

              # Set variable method
              def set_var(name, value)
                comm_file = ENV['HOWZIT_COMM_FILE']
                return unless comm_file

                File.open(comm_file, 'a') do |f|
                  f.puts "VAR:#{name}=#{value}"
                end
              end
            end
          end
        RUBY

        File.write(file, content)
        File.chmod(0o644, file)
      end

      ##
      ## Install Python helper script
      ##
      def install_python_helper(dir)
        file = File.join(dir, 'howzit.py')
        return if File.exist?(file) && !file_stale?(file)

        content = <<~PYTHON
          #!/usr/bin/env python3
          # Howzit helper module for Python

          import os

          class _Logger:
              def _log(self, level, message):
                  comm_file = os.environ.get('HOWZIT_COMM_FILE')
                  if comm_file:
                      with open(comm_file, 'a') as f:
                          f.write(f"LOG:{level}:{message}\\n")

              def info(self, message):
                  self._log('info', message)

              def warn(self, message):
                  self._log('warn', message)

              def error(self, message):
                  self._log('error', message)

              def debug(self, message):
                  self._log('debug', message)

          class Howzit:
              logger = _Logger()

              @staticmethod
              def set_var(name, value):
                  comm_file = os.environ.get('HOWZIT_COMM_FILE')
                  if comm_file:
                      with open(comm_file, 'a') as f:
                          f.write(f"VAR:{name}={value}\\n")
        PYTHON

        File.write(file, content)
        File.chmod(0o644, file)
      end

      ##
      ## Install Perl helper script
      ##
      def install_perl_helper(dir)
        file = File.join(dir, 'howzit.pl')
        return if File.exist?(file) && !file_stale?(file)

        content = <<~PERL
          #!/usr/bin/env perl
          # Howzit helper module for Perl

          package Howzit;

          use strict;
          use warnings;

          sub log {
            my ($level, $message) = @_;
            my $comm_file = $ENV{'HOWZIT_COMM_FILE'};
            return unless $comm_file;

            open(my $fh, '>>', $comm_file) or return;
            print $fh "LOG:$level:$message\\n";
            close($fh);
          }

          sub log_info { log('info', $_[0]); }
          sub log_warn { log('warn', $_[0]); }
          sub log_error { log('error', $_[0]); }
          sub log_debug { log('debug', $_[0]); }

          sub set_var {
            my ($name, $value) = @_;
            my $comm_file = $ENV{'HOWZIT_COMM_FILE'};
            return unless $comm_file;

            open(my $fh, '>>', $comm_file) or return;
            print $fh "VAR:$name=$value\\n";
            close($fh);
          }

          1;
        PERL

        File.write(file, content)
        File.chmod(0o644, file)
      end

      ##
      ## Install Node.js helper script
      ##
      def install_node_helper(dir)
        file = File.join(dir, 'howzit.js')
        return if File.exist?(file) && !file_stale?(file)

        content = <<~JAVASCRIPT
          // Howzit helper module for Node.js

          const fs = require('fs');
          const path = require('path');

          class Logger {
            _log(level, message) {
              const commFile = process.env.HOWZIT_COMM_FILE;
              if (commFile) {
                fs.appendFileSync(commFile, `LOG:${level}:${message}\\n`);
              }
            }

            info(message) {
              this._log('info', message);
            }

            warn(message) {
              this._log('warn', message);
            }

            error(message) {
              this._log('error', message);
            }

            debug(message) {
              this._log('debug', message);
            }
          }

          class Howzit {
            static logger = new Logger();

            static setVar(name, value) {
              const commFile = process.env.HOWZIT_COMM_FILE;
              if (commFile) {
                fs.appendFileSync(commFile, `VAR:${name}=${value}\\n`);
              }
            }
          }

          module.exports = { Howzit, Logger };
        JAVASCRIPT

        File.write(file, content)
        File.chmod(0o644, file)
      end

      ##
      ## Check if a file is stale and needs updating
      ## For now, always update to ensure latest version
      ##
      def file_stale?(_file)
        true
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
