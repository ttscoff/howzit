lib = File.expand_path(File.join('..', 'lib'), __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'howzit/version'

Gem::Specification.new do |spec|
  spec.name          = 'howzit'
  spec.version       = Howzit::VERSION
  spec.authors       = ['Brett Terpstra']
  spec.email         = ['me@brettterpstra.com']
  spec.description   = 'Command line project documentation and task runner'
  spec.summary       = 'Provides a way to access Markdown project notes by topic with query capabilities and the ability to execute the tasks it describes.'
  spec.homepage      = 'https://github.com/ttscoff/howzit'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(features|spec|test)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.0.1'

  spec.add_development_dependency 'bundler', '~> 2.2'
  spec.add_development_dependency 'rake', '~> 11.2'
  spec.add_development_dependency 'bump', '~> 0.5'

  spec.add_development_dependency 'guard', '~> 2.11'
  spec.add_development_dependency 'guard-yard', '~> 2.1'
  spec.add_development_dependency 'guard-rubocop', '~> 1.2'
  spec.add_development_dependency 'guard-rspec', '~> 4.5'

  spec.add_development_dependency 'rubocop', '~> 0.28'
  spec.add_development_dependency 'rspec', '~> 3.1'
  spec.add_development_dependency 'simplecov', '~> 0.9'
  spec.add_development_dependency 'codecov', '~> 0.1'
  spec.add_development_dependency 'fuubar', '~> 2.0'

  spec.add_development_dependency 'yard', '~> 0.9.5'
  spec.add_development_dependency 'redcarpet', '~> 3.2'
  spec.add_development_dependency 'github-markup', '~> 1.3'

  spec.add_runtime_dependency 'mdless', '~> 1.0', '>= 1.0.28'
  spec.add_runtime_dependency 'tty-screen', '~> 0.8'
end
