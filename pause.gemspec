# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pause/version'

Gem::Specification.new do |gem|
  gem.name          = "pause"
  gem.version       = Pause::VERSION
  gem.authors       = ["Atasay Gokkaya", "Paul Henry", "Eric Saxby"]
  gem.email         = %w(atasay@wanelo.com paul@wanelo.com sax@wanelo.com)
  gem.description   = %q(Real time redis rate limiting)
  gem.summary       = %q(Real time redis rate limiting)
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
