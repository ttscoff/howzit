# Ruby Gem Skeleton

[![Gem](https://img.shields.io/gem/v/makenew-ruby_gem.svg)](https://rubygems.org/gems/makenew-ruby_gem)
[![GitHub license](https://img.shields.io/github/license/makenew/ruby-gem.svg)](./LICENSE.txt)
[![Gemnasium](https://img.shields.io/gemnasium/makenew/ruby-gem.svg)](https://gemnasium.com/makenew/ruby-gem)
[![Travis](https://img.shields.io/travis/makenew/ruby-gem.svg)](https://travis-ci.org/makenew/ruby-gem)
[![Codecov](https://img.shields.io/codecov/c/github/makenew/ruby-gem.svg)](https://codecov.io/github/makenew/ruby-gem)
[![Code Climate](https://img.shields.io/codeclimate/github/makenew/ruby-gem.svg)](https://codeclimate.com/github/makenew/ruby-gem)

## Description

Bootstrap a new [Ruby] gem in less than a minute.

[Ruby]: https://www.ruby-lang.org/

### Features

- [Rake] and [Guard] tasks for included tools.
- Gem and dependency management with [Bundler] and [Bump].
- Documentation generation with [YARD].
- Linting with [RuboCop].
- Unit testing with [RSpec].
- Code coverage with [SimpleCov].
- [Travis CI] ready.
- [Keep a CHANGELOG].
- Consistent coding with [EditorConfig].
- Badges from [Shields.io].

[Bump]: https://github.com/gregorym/bump
[Bundler]: http://bundler.io/
[EditorConfig]: http://editorconfig.org/
[Keep a CHANGELOG]: http://keepachangelog.com/
[Guard]: http://guardgem.org/
[Rake]: https://github.com/jimweirich/rake
[RSpec]: http://rspec.info/
[RuboCop]: https://github.com/bbatsov/rubocop
[Shields.io]: http://shields.io/
[SimpleCov]: https://github.com/colszowka/simplecov
[Travis CI]: https://travis-ci.org/
[YARD]: http://yardoc.org/index.html

### Bootstrapping a New Project

1. Clone the master branch of this repository with

   ```
   $ git clone --single-branch https://github.com/makenew/ruby-gem.git new-ruby-gem
   $ cd new-ruby-gem
   ```

   Optionally, reset to the latest [release][Releases] with

   ```
   $ git reset --hard ruby-gem-v2.0.0
   ```

2. Run

   ```
   $ ./makenew.sh
   ```

   and follow the prompts.
   This will replace the boilerplate, delete itself,
   and stage changes for commit.
   This script assumes the project repository will be hosted on GitHub.
   For an alternative location, you must update the URLs manually.

3. Fill in the README Description section.

4. If [choosing a license][Choose a license] other than the one provided:
   update `LICENSE.txt`, the README License section, and the gemspec file
   with your chosen license.

[Choose a license]: http://choosealicense.com/
[Releases]: https://github.com/makenew/ruby-gem/releases
[The Unlicense]: http://unlicense.org/UNLICENSE

### Updating

If you want to pull in future updates from this skeleton,
you can fetch and merge in changes from this repository.

If this repository is already set as `origin`,
rename it to `upstream` with

```
$ git remote rename origin upstream
```

and then configure your `origin` branch as normal.

Otherwise, add this as a new remote with

```
$ git remote add upstream https://github.com/makenew/ruby-gem.git
```

You can then fetch and merge changes with

```
$ git fetch upstream
$ git merge upstream/master
```

#### Changelog

Note that `CHANGELOG.md` is just a template for this skeleton.
The actual changes for this project are documented in the commit history
and summarized under [Releases].

## Installation

Add this line to your application's [Gemfile][Bundler]

```ruby
gem 'makenew-ruby_gem'
```

and update your bundle with

```
$ bundle
```

Or install it yourself with

```
$ gem install makenew-ruby_gem
```

[Bundler]: http://bundler.io/

## Documentation

- [YARD documentation][RubyDoc] is hosted by RubyDoc.info.
- [Interactive documentation][Omniref] is hosted by Omniref.

[RubyDoc]: http://www.rubydoc.info/gems/makenew-ruby_gem
[Omniref]: https://www.omniref.com/ruby/gems/makenew-ruby_gem

## Development and Testing

### Source Code

The [makenew-ruby_gem source] is hosted on GitHub.
Clone the project with

```
$ git clone https://github.com/makenew/ruby-gem.git
```

[makenew-ruby_gem source]: https://github.com/makenew/ruby-gem

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
rake build                 # Build makenew-ruby_gem-2.0.0.gem into the pkg directory
rake bump:current[tag]     # Show current gem version
rake bump:major[tag]       # Bump major part of gem version
rake bump:minor[tag]       # Bump minor part of gem version
rake bump:patch[tag]       # Bump patch part of gem version
rake bump:pre[tag]         # Bump pre part of gem version
rake bump:set              # Sets the version number using the VERSION environment variable
rake clean                 # Remove any temporary products
rake clobber               # Remove any generated files
rake install               # Build and install makenew-ruby_gem-2.0.0.gem into system gems
rake install:local         # Build and install makenew-ruby_gem-2.0.0.gem into system gems without network access
rake release[remote]       # Create tag v2.0.0 and build and push makenew-ruby_gem-2.0.0.gem to Rubygems
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

1. Fork it (https://github.com/makenew/ruby-gem/fork).
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Make changes. Write and run tests.
4. Commit your changes (`git commit -am 'Add some feature'`).
5. Push to the branch (`git push origin my-new-feature`).
6. Create a new Pull Request.

## License

This software can be used freely, see [The Unlicense].
The copyright text appearing below and elsewhere in this repository
is for demonstration purposes only and does not apply to this software.

This Ruby gem is licensed under the MIT license.

## Warranty

This software is provided "as is" and without any express or
implied warranties, including, without limitation, the implied
warranties of merchantibility and fitness for a particular
purpose.
