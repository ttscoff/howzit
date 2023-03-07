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
