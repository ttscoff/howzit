### 2.1.32

2026-01-06 05:21

#### IMPROVED

- Completion output for howzit -L and howzit -T now shows topic titles without parenthetical variable names, making completion lists cleaner and easier to read while still preserving variable information in verbose output (howzit -R).

### 2.1.31

2026-01-06 04:57

#### CHANGED

- Updated Howzit to use XDG_CONFIG_HOME/howzit (or ~/.config/howzit if XDG_CONFIG_HOME is not set) for all configuration files, templates, themes, and script support files instead of ~/.local/share/howzit.

#### NEW

- Added automatic migration prompt that detects existing ~/.local/share/howzit directory and offers to migrate all files to the new config location, merging contents and overwriting existing files in the new location while preserving files that only exist in the new location.
- Added --migrate flag to explicitly trigger migration of legacy ~/.local/share/howzit directory to the new config location.

#### IMPROVED

- Migration prompt now appears during config initialization to catch legacy directories before creating new config files, preventing confusion about file locations.

#### FIXED

- Fixed ArgumentError when topic titles were longer than terminal width by ensuring horizontal rule width calculation never goes negative, clamping to zero when title exceeds available space.

### 2.1.30

2026-01-06 03:55

#### CHANGED

- Updated rubocop from version 0.93.1 to 1.82.1 for Ruby 3.4.4 compatibility
- Updated .rubocop.yml to use plugins syntax instead of require for rubocop extensions
- Updated .rubocop.yml to inherit from .rubocop_todo.yml and removed Max settings that were overriding todo file limits
- Added Security/YAMLLoad exception to .rubocop.yml to allow YAML.load usage (intentionally not using safe_load)
- Added Layout/LineLength exceptions for files with intentionally long lines (bin/howzit, task.rb, util.rb, stringutils.rb, buildnote.rb)
- Run blocks now execute scripts using appropriate interpreter commands instead of always using /bin/sh
- Moved @log_level and @set_var directive processing before task check in sequential execution to ensure they are processed correctly.

#### NEW

- Scripts can now communicate back to Howzit by writing to a communication file specified in HOWZIT_COMM_FILE environment variable, allowing scripts to send log messages (LOG:level:message) and set variables (VAR:KEY=value) that are available for subsequent tasks and conditional logic
- Added ScriptComm module to handle bidirectional communication between scripts and Howzit
- Added @if and @unless conditional blocks that allow content and tasks to be conditionally included or excluded based on evaluated conditions, with support for nested blocks
- Conditional blocks support string comparisons (==, =~ /regex/, *= contains, ^= starts with, $= ends with) and numeric comparisons (==, !=, >, >=, <, <=)
- Conditions can test against metadata keys, environment variables, positional arguments ($1, $2, etc.), named arguments, and script-set variables
- Added special condition checks: git dirty/clean, file exists <path>, dir exists <path>, topic exists <name>, and cwd/working directory
- Conditions support negation with 'not' or '!' prefix
- Added @elsif directive for alternative conditions in @if/@unless blocks, allowing multiple conditional branches
- Added @else directive for fallback branches in conditional blocks when all previous conditions are false
- Conditional blocks now support chaining multiple @elsif statements between @if/@unless and @else
- @elsif and @else work correctly with nested conditional blocks
- Added **= fuzzy match operator for string comparisons that matches if search string characters appear in order within the target string (e.g., "fluffy" **= "ffy" matches)
- Added file contents condition that reads file contents and performs string comparisons using any comparison operator (e.g., file contents VERSION.txt ^= 0.)
- File contents condition supports file paths as variables from metadata, named arguments, or environment variables
- ScriptSupport module provides helper functions (log_info, log_warn, log_error, log_debug, set_var) for bash, zsh, fish, ruby, python, perl, and node scripts in run blocks
- Automatic interpreter detection from hashbang lines in scripts
- Helper script injection into run blocks based on detected interpreter
- Support directory installation at ~/.local/share/howzit/support with language-specific helper scripts
- Add sequential conditional evaluation: @if/@unless blocks are now evaluated after each task runs, allowing variables set by scripts to affect subsequent conditional blocks in the same topic
- Add @log_level(LEVEL) directive to set log level for subsequent tasks in a topic
- Add log_level parameter to @run directives (e.g., @run(script.sh, log_level=debug))
- Add HOWZIT_LOG_LEVEL environment variable support for global log level configuration
- Add emoji and color indicators for log messages (debug, info, warn, error)
- Add comprehensive test coverage for sequential conditional evaluation including @if/@unless/@elsif/@else blocks with variables from run blocks
- Add comprehensive test coverage for log level configuration including @log_level directive, log_level parameter in @run directives, and HOWZIT_LOG_LEVEL environment variable
- Added @set_var directive to set variables in build notes. Takes two comma-separated arguments: variable name (alphanumeric, dashes, underscores only) and value. Variables are available as ${VAR} in subsequent @run directives, run blocks, and @if/@else conditional blocks.
- Added command substitution support to @set_var directive. Values can use backticks (`command`) or $() syntax ($(command)) to execute commands and use their output as the variable value. Commands can reference other variables using ${VAR} syntax.
- Added @set_var directive to set variables directly in build notes, making them available as ${VAR} in subsequent @run directives, run blocks, and @if/@else conditional blocks.
- Added command substitution support to @set_var so values can come from backtick commands (`command`) or $() syntax ($(command)), with command output (whitespace stripped) used as the variable value and ${VAR} substitutions applied inside the command.

#### IMPROVED

- Auto-corrected rubocop style offenses including string literals, redundant self, parentheses, and other correctable issues
- Fixed Lint/Void issue in buildnote.rb by simplifying conditional logic
- Cwd and working directory can now be used with string comparison operators (==, =~, *=, ^=, $=) to check the current directory path
- Conditions now support ${var} syntax in addition to var for consistency with variable substitution syntax
- String comparison operators (*=, ^=, $=) now treat unquoted strings that aren't found as variables as literal strings, allowing simpler syntax like template *= gem instead of template *= "gem"
- Log messages from scripts now display with visual indicators: debug messages show with magnifying glass emoji and dark color, info with info emoji and cyan, warnings with warning emoji and yellow, errors with X emoji and red
- Log level filtering now properly applies to script-to-howzit communication messages, showing only messages at or above the configured level
- Conditional blocks (@if/@unless/@elsif/@else) now re-evaluate after each task execution, enabling dynamic conditional flow based on variables set by preceding tasks
- Improve task directive parsing by refactoring to use unless/next pattern for better code organization and fixing @log_level directive handling
- Improve Directive#to_task to properly handle title rendering with variable substitution, argument parsing for include tasks, and action escaping for copy tasks
- Processed @set_var directives before task creation in topics without conditionals so variable substitution in @run actions works as expected even in the non-sequential execution path.

#### FIXED

- Resolved NameError for 'white' color method by generating escape codes directly from configured_colors hash instead of calling dynamically generated methods
- Fixed infinite recursion in ConsoleLogger by using $stderr.puts directly instead of calling warn method recursively
- Color template method now properly respects coloring? setting and returns empty strings when coloring is disabled
- Resolved test failures caused by Howzit.buildnote caching stale instances by resetting @buildnote in spec_helper before each test
- Fixed bug where @end statements failed to close conditional blocks when conditions evaluated to false, preventing subsequent conditional blocks from working correctly
- Fixed issue where named arguments from topic titles were not available when evaluating conditions in conditional blocks
- Suppressed EPIPE errors that occur when writing to stdout/stderr after pipes are closed, preventing error messages from appearing in terminal output
- Fix @elsif and @else conditional blocks not executing tasks when parent @if condition is false by correctly tracking branch indices and skipping parent @if index in conditional path evaluation
- Fix clipboard copy test failing due to cached console logger instance not updating when log_level option changes
- Fixed variable persistence issue in sequential execution where Howzit.named_arguments was being reset on each iteration, causing @set_var variables to be lost.
- Ensured variables set by @set_var and helper scripts persist correctly across sequential conditional evaluation by merging topic named arguments into Howzit.named_arguments instead of overwriting them.

### 2.1.29

2026-01-01 06:55

#### CHANGED

- Updated rubocop from version 0.93.1 to 1.82.1 for Ruby 3.4.4 compatibility
- Updated .rubocop.yml to use plugins syntax instead of require for rubocop extensions
- Updated .rubocop.yml to inherit from .rubocop_todo.yml and removed Max settings that were overriding todo file limits
- Added Security/YAMLLoad exception to .rubocop.yml to allow YAML.load usage (intentionally not using safe_load)
- Added Layout/LineLength exceptions for files with intentionally long lines (bin/howzit, task.rb, util.rb, stringutils.rb, buildnote.rb)

#### NEW

- Scripts can now communicate back to Howzit by writing to a communication file specified in HOWZIT_COMM_FILE environment variable, allowing scripts to send log messages (LOG:level:message) and set variables (VAR:KEY=value) that are available for subsequent tasks and conditional logic
- Added ScriptComm module to handle bidirectional communication between scripts and Howzit
- Added @if and @unless conditional blocks that allow content and tasks to be conditionally included or excluded based on evaluated conditions, with support for nested blocks
- Conditional blocks support string comparisons (==, =~ /regex/, *= contains, ^= starts with, $= ends with) and numeric comparisons (==, !=, >, >=, <, <=)
- Conditions can test against metadata keys, environment variables, positional arguments ($1, $2, etc.), named arguments, and script-set variables
- Added special condition checks: git dirty/clean, file exists <path>, dir exists <path>, topic exists <name>, and cwd/working directory
- Conditions support negation with 'not' or '!' prefix
- Added @elsif directive for alternative conditions in @if/@unless blocks, allowing multiple conditional branches
- Added @else directive for fallback branches in conditional blocks when all previous conditions are false
- Conditional blocks now support chaining multiple @elsif statements between @if/@unless and @else
- @elsif and @else work correctly with nested conditional blocks
- Added **= fuzzy match operator for string comparisons that matches if search string characters appear in order within the target string (e.g., "fluffy" **= "ffy" matches)
- Added file contents condition that reads file contents and performs string comparisons using any comparison operator (e.g., file contents VERSION.txt ^= 0.)
- File contents condition supports file paths as variables from metadata, named arguments, or environment variables

#### IMPROVED

- Auto-corrected rubocop style offenses including string literals, redundant self, parentheses, and other correctable issues
- Fixed Lint/Void issue in buildnote.rb by simplifying conditional logic
- Cwd and working directory can now be used with string comparison operators (==, =~, *=, ^=, $=) to check the current directory path
- Conditions now support ${var} syntax in addition to var for consistency with variable substitution syntax
- String comparison operators (*=, ^=, $=) now treat unquoted strings that aren't found as variables as literal strings, allowing simpler syntax like template *= gem instead of template *= "gem"

#### FIXED

- Resolved NameError for 'white' color method by generating escape codes directly from configured_colors hash instead of calling dynamically generated methods
- Fixed infinite recursion in ConsoleLogger by using $stderr.puts directly instead of calling warn method recursively
- Color template method now properly respects coloring? setting and returns empty strings when coloring is disabled
- Resolved test failures caused by Howzit.buildnote caching stale instances by resetting @buildnote in spec_helper before each test
- Fixed bug where @end statements failed to close conditional blocks when conditions evaluated to false, preventing subsequent conditional blocks from working correctly
- Fixed issue where named arguments from topic titles were not available when evaluating conditions in conditional blocks
- Suppressed EPIPE errors that occur when writing to stdout/stderr after pipes are closed, preventing error messages from appearing in terminal output

### 2.1.28

2025-12-31 10:21

#### CHANGED

- Refactored code to use more concise unless statement syntax

#### NEW

- Added "token" matching mode for multi-word searches that matches words in order

#### IMPROVED

- Enhanced fuzzy matching to use token-based approach for multi-word searches
- Default partial matching now uses token-based matching for better multi-word search results

#### FIXED

- Improved error handling when topics are not found or invalid
- Fixed topic selection when using interactive choose mode with topics that have named arguments
- Added nil checks to prevent errors when arguments array is nil
- Improved handling of empty search terms to prevent matching all topics

### 2.1.27

2025-12-26 08:59

#### IMPROVED

- Task titles now support variable substitution using ${VAR} syntax, so titles like "@run(echo test) Title with ${var}" will replace ${var} with its value from topic metadata. This applies to all task types (run, copy, open, include) and code block titles.

#### FIXED

- Task and topic names containing dollar signs (like $text$ or ${VAR}) now display correctly in run report output without causing color code interpretation issues. Dollar signs are properly escaped during formatting and unescaped in the final output.

### 2.1.26

2025-12-26 04:53

#### FIXED

- Bash script variables in run blocks now preserve ${VAR} syntax when the variable is not defined by howzit, allowing bash to handle them normally instead of being replaced with empty strings.

### 2.1.25

2025-12-19 07:41

#### NEW

- Added default metadata support to automatically run topics when executing `howzit --run` with no arguments. Supports multiple comma-separated topics with optional bracketed arguments (e.g., `default: Build Project, Run Tests[verbose]`).

#### FIXED

- Task titles are now correctly displayed in run reports and "Running" messages instead of showing the command. When a title is provided after @run or @include directives (e.g., `@run(ls) List directory`), the title is used throughout.
- Fixed color code interpretation issues when task or topic names contain dollar signs or braces. These characters are now properly escaped to prevent them from being interpreted as color template codes.
- Fixed issue where task titles containing braces would show literal `{x}` in output due to color template parsing.

### 2.1.24

2025-12-13 07:11

#### CHANGED

- Run summary now displays as simple list with emoji status indicators

#### IMPROVED

- Use horizontal rule (***) as separator instead of box borders

### 2.1.23

2025-12-13 06:38

#### CHANGED

- Output format changed from bordered text to markdown table

#### NEW

- Added emoji header () to run report table

#### IMPROVED

- Status indicators now use emoji (/) instead of text symbols
- Failure messages now show "(exit code X)" instead of "Failed: exit code X"

### 2.1.22

2025-12-13 06:14

#### NEW

- Template selection menu when creating new build notes
- Prompt for required template variables during note creation
- Gum support as fallback for menus and text input

#### IMPROVED

- Fuzzy matching for template names when fzf unavailable
- Text input uses Readline for proper line editing (backspace, ctrl-a/e)

### 2.1.21

2025-12-13 05:03

#### NEW

- Prefer exact whole-word topic matches over fuzzy matches
- Display run summary after executing tasks

#### IMPROVED

- Topic matching now handles colons/commas in topic titles
- Smart splitting of multiple topics preserves separators in titles
- Single match from choose now auto-selects without menu
- Combined output from multiple topics paginated together
- Menu prompt shows the search term being matched

#### FIXED

- String uncolor deleting characters
- Broken pipe error when quitting pager early

### 2.1.20

2025-12-13 05:01

#### NEW

- Prefer exact whole-word topic matches over fuzzy matches
- Display run summary after executing tasks

#### IMPROVED

- Topic matching now handles colons/commas in topic titles
- Smart splitting of multiple topics preserves separators in titles
- Single match from choose now auto-selects without menu
- Combined output from multiple topics paginated together
- Menu prompt shows the search term being matched

#### FIXED

- String uncolor deleting characters
- Broken pipe error when quitting pager early

### 2.1.19

2025-12-13 05:01

#### NEW

- Prefer exact whole-word topic matches over fuzzy matches
- Display run summary after executing tasks

#### IMPROVED

- Topic matching now handles colons/commas in topic titles
- Smart splitting of multiple topics preserves separators in titles
- Single match from choose now auto-selects without menu
- Combined output from multiple topics paginated together
- Menu prompt shows the search term being matched

#### FIXED

- String uncolor deleting characters
- Broken pipe error when quitting pager early

### 2.1.18

2025-01-01 09:53

#### IMPROVED

- Include named arguments when listing runnable topics

### 2.1.16

2024-08-13 10:59

#### IMPROVED

- Add extra linebreak before @include headers

### 2.1.15

2024-08-07 13:10

#### FIXED

- Prompt for editor when $EDITOR is not defined
- Use exec for CLI editors provide a separate process
- Remove tests for editor in main executable

### 2.1.14

2024-08-06 16:36

#### IMPROVED

- Better algorithm for best match when `multiple_matches: best` is set

### 2.1.13

2024-08-05 12:04

### 2.1.12

2024-08-05 12:01

### 2.1.11

2024-08-05 12:01

### 2.1.10

2024-04-09 14:59

#### NEW

- --no option (opposite of --yes) to answer no to all yes/no prompts

### 2.1.9

2023-09-07 11:02

#### NEW

- Add --templates-c to get a completion-compatible list of available templates

### 2.1.8

2023-05-31 11:58

#### FIXED

- Colors.rb error when code is integer

### 2.1.7

2023-05-29 12:59

#### FIXED

- Handle variable replacements on lines containing colons outside of variable

### 2.1.6

2023-05-29 12:42

#### FIXED

- Remove empty undefined variables with no default

### 2.1.5

2023-04-12 15:13

#### FIXED

- Allow tilde in path to editor

### 2.1.4

2023-03-07 12:52

#### NEW

- A theme file is automatically created where you can change the default output of any color that Howzit outputs. They can be 2-3 digit ANSI escape codes, or '#XXXXXX' RGB hex codes

### 2.1.3

2023-03-07 11:21

#### FIXED

- Annoying warning about color template format string having too many arguments

### 2.1.2

2023-03-07 10:24

#### IMPROVED

- Merge metadata into named variables so they're also available as ${NAME}

### 2.1.1

2023-03-07 09:47

#### FIXED

- Allow variables names to contain numbers and underscores

### 2.1.0

2023-03-07 09:24

#### NEW

- Use TOPIC_TITLE (var1, var2) to have access to ${var1} ${var2} in text and scripts, populated with positional variables on the command line
- Add a default (fallback) value to any variable placeholder with ${var_name:default value}

### 2.0.34

2023-01-15 13:32

#### FIXED

- Fail to partial match include commands after running fzf

### 2.0.33

2023-01-15 13:26

### 2.0.32

2023-01-15 10:46

#### IMPROVED

- When using fzf chooser, make matching exact to avoid running multiple topics

### 2.0.31

2022-08-31 07:17

#### FIXED

- Color template formatting of task output

### 2.0.30

2022-08-31 07:15

#### FIXED

- Formatting of --help and --version commands

### 2.0.29

2022-08-30 04:20

#### NEW

- --yes flag will answer yes to all prompts when executing
- --force flag will continue executing directives after an error

#### IMPROVED

- A non-zero exit status on a run directive will stop processing additional directives
- A little extra output formatting, more descriptive results logging

### 2.0.28

2022-08-29 18:42

#### IMPROVED

- If a topic runs multiple directives, stop processing them if one returns a non-zero exit status

### 2.0.27

2022-08-23 12:25

#### IMPROVED

- Code cleanup

### 2.0.26

2022-08-23 11:36

#### IMPROVED

- Add ctrl-a/d bindings to fzf menu for select/deselect all

### 2.0.25

2022-08-09 12:46

#### FIXED

- Template metadata inheritence

### 2.0.24

2022-08-09 09:04

#### FIXED

- Avoid reading upstream files multiple times

### 2.0.23

2022-08-09 05:51

#### FIXED

- --grep function regression

### 2.0.22

2022-08-08 13:49

#### IMPROVED

- Paginate output of --templates

#### FIXED

- --templates attempting to create new build note
- Fix handling of paths when the same as note_file

### 2.0.21

2022-08-08 13:16

#### IMPROVED

- Use os-agnostic copy function for --hook
- Rename link title for --hook

### 2.0.20

2022-08-08 11:38

#### NEW

- --hook command for macOS to copy a link to the build note to clipboard

#### FIXED

- Error on --edit-config
- Fzf preview empty

### 2.0.19

2022-08-08 06:18

#### IMPROVED

- Sort options in help output

### 2.0.18

2022-08-08 03:48

#### NEW

- Use --ask to require confirmation of all tasks when running a topic

### 2.0.17

2022-08-07 06:09

### 2.0.16

2022-08-07 06:05

#### NEW

- --edit-template NAME will open a template in your editor, offering to create it if missing

#### FIXED

- If --show-code is given (or :show_all_code: is set to true), show content of @directives instead of title

### 2.0.15

2022-08-05 17:16

#### IMPROVED

- -R can take an argument to filter results
- Show a topic preview when using fzf to select from available topics
- Paginate help output
- Refactor Topic.run

#### FIXED

- Invalid options for more pager
- Error running grep command
- Show method not accepting paginate option

### 2.0.14

2022-08-05 13:24

#### FIXED

- Travis CI fixes

### 2.0.13

2022-08-05 13:19

#### IMPROVED

- Add tests for more ruby versions via Docker

### 2.0.12

2022-08-05 11:27

#### IMPROVED

- Show how many tasks will be included when requesting confirmation for an include? directive

### 2.0.11

2022-08-05 11:21

#### IMPROVED

- Update fish completions with all current command line options

### 2.0.10

2022-08-05 08:17

#### IMPROVED

- Provide more helpful feedback if no content is found in build note
- Confirm whether the user wants to create a new note when one isn't found

### 2.0.9

2022-08-05 07:29

#### IMPROVED

- Avoid error trace on interrupt
- Better stty settings for y/n prompt
- Better coloring of default options in dialogs

#### FIXED

- Encoding issues with older ruby versions
- Globbing for build notes was picking up files that contained "build" but not at the beginning of the filename

### 2.0.8

2022-08-04 13:28

#### FIXED

- Bugfixes

### 2.0.7

2022-08-04 13:04

#### NEW

- --debug flag (shortcut for :log_level: 0)

#### IMPROVED

- Console output now gets log levels, so :log_level: config option and --quiet/verbose have more utility

### 2.0.6

2022-08-04 11:08

### 2.0.5

2022-08-04 10:50

#### NEW

- Make any task optional when running by adding a ? (@open?(...))
- Optional tasks default to yes when you hit enter, invert by using a ! (@open?!(...)) to make default "no"

#### FIXED

- Replace escaped newlines in task list output so that they don't trigger a newline in the shell

### 2.0.4

2022-08-04 06:25

#### IMPROVED

- Ask to open new buildnote for editing after creation

#### FIXED

- Loop when creating new buildnote

### 2.0.3

2022-08-04 05:31

#### IMPROVED

- General code cleanup
- Attempt at os agnostic @copy command, hopefully works on Windows and Linux systems

#### FIXED

- Not displaying action if title is missing

### 2.0.2

2022-08-03 18:26

#### IMPROVED

- If a title is provided after an @command, display it instead of the contents when viewing

### 2.0.1

2022-08-03 12:46

#### FIXED

- Failure to create new notes file when one isn't found

### 2.0.0

2022-08-03 12:37

#### FIXED

- Positional arguments not rendering in tasks
- Fix degradation where arguments are empty

### 1.2.19

2022-08-03 12:18

#### FIXED

- --config-get returning non-default options

### 1.2.18

2022-08-03 12:13

#### FIXED

- Unwritable content property

### 1.2.17

2022-08-03 12:10

#### FIXED

- Variables in topics not being replaced with metadata
- Allow default response in yes/no prompt

### 1.2.16

2022-08-03 11:41

#### IMPROVED

- Complete code refactoring

#### FIXED

- Multiple includes of upstream files when templates are specified

### 1.2.15

2022-08-02 11:59

#### NEW

- Option to set :header_format: to block for alternate topic title appearance

#### FIXED

- Missing spacing around topic titles when displaying multiple topics

### 1.2.14

2022-08-02 11:01

#### NEW

- Config option and flag to determine how to handle multiple results (first, best, all, choose)
- --config-get and --config-set flags for working with config options

#### IMPROVED

- Allow multiple selections when using fzf
- Clean up newlines in output

### 1.2.13

2022-08-01 20:50

### 1.2.12

2022-08-01 16:23

#### IMPROVED

- Replace ANSI escape codes with color template system
- When @including an external file, if the file doesn't contain any level 2+ headers, import it as plain text.

### 1.2.11

2022-08-01 08:23

#### IMPROVED

- Code cleanup and refactoring

### 1.2.10

2022-08-01 07:45

#### FIXED

- Headline formatting when iTerm markers are inserted

### 1.2.8

2022-08-01 07:01

#### FIXED

- Frozen string error

### 1.2.6

2022-08-01 06:09

#### NEW

- Use @before...@end and @after...@end to specify prerequisites and a post-run message. Topics with @before will require y/n verification before running

#### FIXED

- ITerm markers weren't being inserted when paging was off

### 1.2.3

2022-07-31 14:20

#### IMPROVED

- Don't include a topic multiple times in one display
- Don't execute nested topics more than once
- Indicate nested includes in headers
- Code cleanup

### 1.2.2

2022-07-31 08:56

- Add -F option to pager setup (quit if less than one screen)

### 1.2.1

2022-07-31 05:12

- Add handling for delta pager to not clear screen on exit

### 1.2.0

2022-07-31 04:59

- Add grep feature, searches topic/content for pattern and displays matches (selection menu if multiple matches)

### 1.1.27

2022-01-17 11:45

#### NEW

- Use fzf for menus if available
- "@run() TITLE" will show TITLE instead of command when listing runnable topics
- @include(FILENAME) will import an external file if the path exists

### 1.1.26

- Fix for error in interactive build notes creation

### 1.1.25

- Hide run block contents by default
- :show_all_code: config setting to include run block contents
- --show-code flag to display run block contents at runtime
- Modify include display

### 1.1.24

- Use ~/.config/howzit/ignore.yaml to ignore patterns when scanning for build notes
- Use `required` and `optional` keys in templates to request that metadata be defined when importing
- Allow templates to include other templates

### 1.1.23

- Add flags to allow content to stay onscreen after exiting pager (less and bat)

### 1.1.21

- Merge directive and block handling so execution order is sequential

### 1.1.20

- Template functionality for including common tasks/topics

### 1.1.19

- Add `--upstream` option to traverse up parent directories for additional build notes

### 1.1.15

- Code refactoring/cleanup
- Rename "sections" to "topics"
- If no match found for topic search, only show error (`:show_all_on_error: false` option)

### 1.1.14

- Fix removal of non-alphanumeric characters from titles
- -s/--select option to display a menu of all available topics
- Allow arguments to be passed after `--` for variable substitution
- Allow --matching TYPE to match first non-ambigous keyword match

### 1.1.13

- --matching [fuzzy,beginswith,partial,exact] flag
- --edit-config flag
- sort flags in help

### 1.1.12

- After consideration, remove full fuzzy matching. Too many positives for shorter strings.

### 1.1.11

- Add full fuzzy matching for topic titles
- Add `@include(TOPIC)` command to import another topic's tasks

### 1.1.10

- Add config file for default options

### 1.1.9

- Use `system` instead of `exec` to allow multiple @run commands
- Add code block runner

### 1.1.8

- Add `-e/--edit` flag to open build notes in $EDITOR

### 1.1.7

- Use `exec` for @run commands to allow interactive processes (e.g. vim)

### 1.1.6

- Add option for outputting title with notes
- Add option for outputting note title only

### 1.1.4

- Fix for "topic not found" when run with no arguments

### 1.1.1

- Reorganize and rename long output options
- Fix wrapping long lines without spaces

### 1.1.0

- Add -R switch for listing "runnable" topics
- Add -T switch for completion-compatible listing of "runnable" topics
- Add -L switch for completion-compatible listing of all topics

### 1.0.1

- Allow topic matching within title, not just at start
- Remove formatting of topic text for better compatibility with mdless/mdcat
- Add @run() syntax to allow executable commands
- Add @copy() syntax to copy text to clipboard
- Add @url/@open() syntax to open urls/files, OS agnostic (hopefully)
- Add support for mdless/mdcat
- Add support for pager
- Offer to create skeleton buildnotes if none found
- Set iTerm 2 marks for navigation when paging is disabled
- Wrap output with option to specify width (default 80, 0 to disable)
