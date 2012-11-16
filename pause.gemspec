# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pause/version'

Gem::Specification.new do |gem|
  gem.name          = "pause"
  gem.version       = Pause::VERSION
  gem.authors       = ["Atasay Gokkaya", "Paul Henry", "Eric Saxby", "Konstantin Gredeskoul"]
  gem.email         = %w(atasay@wanelo.com paul@wanelo.com sax@wanelo.com kig@wanelo.com)
  gem.description   = %q(Real time rate limiting for multi-process ruby environments based on Redis)
  gem.summary       = %q(RReal time rate limiting for multi-process ruby environments based on Redis)
  gem.homepage      = "https://github.com/wanelo/pause"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'redis'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'fakeredis'
  gem.add_development_dependency 'timecop'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'rb-fsevent'
end
