# -*- encoding: utf-8 -*-
require File.expand_path('../lib/webmock/version', __FILE__)

Gem::Specification.new do |gem|
  gem.add_development_dependency 'curb', '~> 0.7'
  gem.add_development_dependency 'em-http-request', '~> 0.2'
  gem.add_development_dependency 'httpclient', '~> 2.1'
  gem.add_development_dependency 'patron', '~> 0.4'
  gem.add_development_dependency 'rake', '~> 0.8'
  gem.add_development_dependency 'rspec', '~> 2.0'
  gem.add_runtime_dependency 'addressable', ['> 2.2.5', '~> 2.2']
  gem.add_runtime_dependency 'crack', '~> 0.1.7'
  gem.authors = ["Bartosz Blimke"]
  gem.description = %q{WebMock allows stubbing HTTP requests and setting expectations on HTTP requests.}
  gem.email = ['bartosz.blimke@gmail.com']
  gem.extra_rdoc_files = [
    "LICENSE",
    "README.md",
  ]
  gem.files = `git ls-files`.split("\n")
  gem.homepage = 'http://github.com/bblimke/webmock'
  gem.name = 'webmock'
  gem.require_paths = ['lib']
  gem.required_rubygems_version = Gem::Requirement.new('>= 1.3.6')
  gem.summary = %q{Library for stubbing HTTP requests in Ruby.}
  gem.version = WebMock::VERSION
end
