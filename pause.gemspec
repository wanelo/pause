# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pause/version'

Gem::Specification.new do |gem|
  gem.name          = 'pause'
  gem.version       = Pause::VERSION
  gem.authors       = ['Atasay Gokkaya', 'Paul Henry', 'Eric Saxby', 'Konstantin Gredeskoul']
  gem.email         = %w(atasay@wanelo.com paul@wanelo.com sax@ericsaxby.com kigster@gmail.com)
  gem.summary       = %q(Fast and efficient real time rate limiting library for multi-process ruby environments based on Redis)
  gem.description   = %q(This gem provides flexible and easy to use interface to define rate checks, register events as they come, and verify if the rate limit is reached. Multiple checks for the same metric are easily supported.)
  gem.homepage      = 'https://github.com/wanelo/pause'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'redis'
  gem.add_dependency 'hiredis'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'fakeredis'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'pry-nav'
  gem.add_development_dependency 'rb-fsevent'
  gem.add_development_dependency 'timecop'
  gem.add_development_dependency 'rake'
end
