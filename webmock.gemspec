# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'webmock/version'

Gem::Specification.new do |s|
  s.name        = 'webmock'
  s.version     = WebMock::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Bartosz Blimke']
  s.email       = ['bartosz.blimke@gmail.com']
  s.homepage    = 'http://github.com/bblimke/webmock'
  s.summary     = %q{Library for stubbing HTTP requests in Ruby.}
  s.description = %q{WebMock allows stubbing HTTP requests and setting expectations on HTTP requests.}
  s.license     = "MIT"

  s.rubyforge_project = 'webmock'

  s.add_dependency 'addressable', '>= 2.2.7'
  s.add_dependency 'crack', '>=0.3.2'

  s.add_development_dependency 'rspec',           '~> 2.10'
  s.add_development_dependency 'httpclient',      '>= 2.2.4'
  s.add_development_dependency 'patron',          '>= 0.4.18' unless RUBY_PLATFORM =~ /java/
  s.add_development_dependency 'em-http-request', '>= 1.0.2'
  s.add_development_dependency 'em-synchrony',    '>= 1.0.0' if RUBY_VERSION >= "1.9"
  s.add_development_dependency 'curb',            '>= 0.8.0' unless RUBY_PLATFORM =~ /java/
  s.add_development_dependency 'typhoeus',        '>= 0.5.0' unless RUBY_PLATFORM =~ /java/
  s.add_development_dependency 'excon',           '>= 0.11.0'
  s.add_development_dependency 'minitest',        '>= 2.2.2'
  s.add_development_dependency 'rdoc',            ((RUBY_VERSION == '1.8.6') ? '<= 3.5.0' : '>3.5.0')

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
end
