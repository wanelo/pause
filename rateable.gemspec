# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rateable/version'

Gem::Specification.new do |gem|
  gem.name          = "rateable"
  gem.version       = Rateable::VERSION
  gem.authors       = ["Atasay Gokyaka", "Paul Henry"]
  gem.email         = %w(atasay@wanelo.com paul@wanelo.com)
  gem.description   = %q(Real time redis rate limiting)
  gem.summary       = %q(Real time redis rate limiting)
  gem.homepage      = "https://github.com/wanelo/rateable"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'redis'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'fakeredis'
  gem.add_development_dependency 'timecop'
end
