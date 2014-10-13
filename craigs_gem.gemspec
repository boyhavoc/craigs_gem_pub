# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'craigs_gem/version'

Gem::Specification.new do |spec|
  spec.name          = "craigs_gem"
  spec.version       = CraigsGem::VERSION
  spec.authors       = ["Cass"]
  spec.email         = ["cass@rubyeffect.com"]
  spec.summary       = %q{Ruby gem for Craigslist bulk posting API}
  spec.description   = %q{Publish multiple postings to Craigslist in a single http post!}
  spec.homepage      = "https://github.com/boyhavoc/craigsgem"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib", "config"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10.3"
  spec.add_development_dependency "httparty", "~> 0.13"
  spec.add_development_dependency "nokogiri", '~> 1.6', '>= 1.6.3'
  spec.add_development_dependency "webmock", "~> 1.18"
end
