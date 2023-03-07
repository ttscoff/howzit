# Howzit

[![Gem](https://img.shields.io/gem/v/howzit.svg)](https://rubygems.org/gems/howzit)
[![Travis](https://api.travis-ci.com/ttscoff/howzit.svg?branch=main)](https://travis-ci.org/makenew/ruby-gem)
[![GitHub license](https://img.shields.io/github/license/ttscoff/howzit.svg)](./LICENSE.txt)

A command-line reference tool for tracking project build systems

Howzit is a tool that allows you to keep Markdown-formatted notes about a project's tools and procedures. It functions as an easy lookup for notes about a particular task, as well as a task runner to automatically execute appropriate commands.

<!--README-->

## Features

- Match topic titles with any portion of title
- Automatic pagination of output, with optional Markdown highlighting
- Use `@run()`, `@copy()`, and `@open()` to perform actions within a build notes file
- Use `@include()` to import another topic's tasks
- Use fenced code blocks to include/run embedded scripts
- Sets iTerm 2 marks on topic titles for navigation when paging is disabled
- Inside of git repositories, howzit will work from subdirectories, assuming build notes are in top level of repo
- Templates for easily including repeat tasks
- Grep topics for pattern and choose from matches
- Use positional and named variables when executing tasks

## Getting Started

### Prerequisites

- Ruby 2.4+ (It probably works on older Rubys, but is untested prior to 2.4.1.)
- Optional: if [`fzf`](https://github.com/junegunn/fzf) is available, it will be used for handling multiple choice selections
- Optional: if [`bat`](https://github.com/sharkdp/bat) is available it will page with that
- Optional: [`mdless`](https://github.com/ttscoff/mdless) or [`mdcat`](https://github.com/lunaryorn/mdcat) for formatting output

### Installing

You can install `howzit` by running:

    gem install howzit

If you run into permission errors using the above command, you'll need to either use `sudo` (`sudo gem install howzit`) or if you're using Homebrew, you have the option to install via [brew-gem](https://github.com/sportngin/brew-gem):

    brew install brew-gem
    brew gem install howzit

### Usage

[See the wiki](https://github.com/ttscoff/howzit/wiki) for documentation.

## Author

**Brett Terpstra** - [brettterpstra.com](https://brettterpstra.com)

## License

This project is licensed under the MIT License - see the [LICENSE.txt](LICENSE.txt) file for details.

<!--END README-->

## Warranty

This software is provided "as is" and without any express or
implied warranties, including, without limitation, the implied
warranties of merchantibility and fitness for a particular
purpose.

## Documentation

- [Howzit Wiki][Wiki].
- [YARD documentation][RubyDoc] is hosted by RubyDoc.info.
- [Interactive documentation][Omniref] is hosted by Omniref.

[Wiki]: https://github.com/ttscoff/howzit/wiki
[RubyDoc]: http://www.rubydoc.info/gems/howzit
[Omniref]: https://www.omniref.com/ruby/gems/howzit

## Development and Testing

### Source Code

The [howzit source] is hosted on GitHub.
Clone the project with

```
$ git clone https://github.com/ttscoff/howzit.git
```

[howzit source]: https://github.com/ttscoff/howzit

### Requirements

You will need [Ruby] with [Bundler].

Install the development dependencies with

```
$ bundle
```

[Bundler]: http://bundler.io/
[Ruby]: https://www.ruby-lang.org/

### Rake

Run `$ rake -T` to see all Rake tasks.

```
rake build                 # Build howzit-2.0.1.gem into the pkg directory
rake bump:current[tag]     # Show current gem version
rake bump:major[tag]       # Bump major part of gem version
rake bump:minor[tag]       # Bump minor part of gem version
rake bump:patch[tag]       # Bump patch part of gem version
rake bump:pre[tag]         # Bump pre part of gem version
rake bump:set              # Sets the version number using the VERSION environment variable
rake clean                 # Remove any temporary products
rake clobber               # Remove any generated files
rake install               # Build and install howzit-2.0.1.gem into system gems
rake install:local         # Build and install howzit-2.0.1.gem into system gems without network access
rake release[remote]       # Create tag v2.0.1 and build and push howzit-2.0.1.gem to Rubygems
rake rubocop               # Run RuboCop
rake rubocop:auto_correct  # Auto-correct RuboCop offenses
rake spec                  # Run RSpec code examples
rake test                  # Run test suite
rake yard                  # Generate YARD Documentation
```

### Guard

Guard tasks have been separated into the following groups:
`doc`, `lint`, and `unit`.
By default, `$ guard` will generate documentation, lint, and run unit tests.

## Contributing

Please submit and comment on bug reports and feature requests.

To submit a patch:

1. Fork it (https://github.com/ttscoff/howzit/fork).
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Make changes. Write and run tests.
4. Commit your changes (`git commit -am 'Add some feature'`).
5. Push to the branch (`git push origin my-new-feature`).
6. Create a new Pull Request.

