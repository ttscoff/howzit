lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'makenew/version'

Gem::Specification.new do |spec|
  spec.name          = 'makenew-ruby_gem'
  spec.version       = Makenew::VERSION
  spec.authors       = ['Evan Sosenko']
  spec.email         = ['razorx@evansosenko.com']
  spec.description   = %q{Ruby gem skeleton.}
  spec.summary       = %q{Ruby gem skeleton from makenew.}
  spec.homepage      = 'https://github.com/makenew/ruby-gem'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(features|spec|test)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.0.0'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake', '~> 10.4'
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

  spec.add_development_dependency 'yard', '~> 0.8.7'
  spec.add_development_dependency 'yard-redcarpet-ext', '~> 0.0.3'
  spec.add_development_dependency 'redcarpet', '~> 3.2'
  spec.add_development_dependency 'github-markup', '~> 1.3'
end
