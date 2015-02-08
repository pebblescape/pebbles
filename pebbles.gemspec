# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pebbles/version'

Gem::Specification.new do |spec|
  spec.name          = "pebbles"
  spec.version       = Pebbles::VERSION
  spec.authors       = ["Kristjan Rang"]
  spec.email         = ["mail@rang.ee"]
  spec.summary       = %q{CLI client for Pebblscape}
  spec.description   = ''
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler",  "~> 1.7"
  spec.add_development_dependency "rake",     "~> 10.0"
  
  spec.add_dependency "excon",    "~> 0.44.1"
  spec.add_dependency "launchy",  "~> 2.4.3"
end
