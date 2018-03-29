# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pause/version'

Gem::Specification.new do |gem|
  gem.name          = 'pause'
  gem.version       = Pause::VERSION
  gem.authors       = ['Atasay Gokkaya', 'Paul Henry', 'Eric Saxby', 'Konstantin Gredeskoul']
  gem.email         = %w(atasay@wanelo.com paul@wanelo.com sax@ericsaxby.com kigster@gmail.com)
  gem.summary       = %q(Fast, scalable, and flexible real time rate limiting library for distributed Ruby environments backed by Redis.)
  gem.description   = %q(This gem provides highly flexible and easy to use interface to define rate limit checks, register events as they come, and verify if the rate limit is reached. Multiple checks for the same metric are easily supported. This gem is used at very high scale on several popular web sites.)
  gem.homepage      = 'https://github.com/kigster/pause'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'redis'
  gem.add_dependency 'hiredis'
  gem.add_dependency 'colored2'

  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'fakeredis'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'timecop'
  gem.add_development_dependency 'rake'
end
