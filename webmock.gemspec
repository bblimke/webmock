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

  s.metadata = {
    'bug_tracker_uri'   => 'https://github.com/bblimke/webmock/issues',
    'changelog_uri'     => "https://github.com/bblimke/webmock/blob/v#{s.version}/CHANGELOG.md",
    'documentation_uri' => "https://www.rubydoc.info/gems/webmock/#{s.version}",
    'source_code_uri'   => "https://github.com/bblimke/webmock/tree/v#{s.version}",
    'wiki_uri'          => 'https://github.com/bblimke/webmock/wiki'
  }

  s.required_ruby_version = '>= 2.0'

  s.add_dependency 'addressable', '>= 2.3.6'
  s.add_dependency 'crack', '>= 0.3.2'
  s.add_dependency 'hashdiff', ['>= 0.4.0', '< 2.0.0']

  unless RUBY_PLATFORM =~ /java/
    s.add_development_dependency 'patron',   '>= 0.4.18'
    s.add_development_dependency 'curb',     '>= 0.7.16'
    s.add_development_dependency 'typhoeus', '>= 0.5.0'
  end

  s.add_development_dependency 'http',            '>= 0.8.0'
  s.add_development_dependency 'manticore',       '>= 0.5.1' if RUBY_PLATFORM =~ /java/
  s.add_development_dependency 'rack',            ((RUBY_VERSION < '2.2.2') ? '1.6.0' : '> 1.6')
  s.add_development_dependency 'rspec',           '>= 3.1.0'
  s.add_development_dependency 'httpclient',      '>= 2.2.4'
  s.add_development_dependency 'em-http-request', '>= 1.0.2'
  s.add_development_dependency 'em-synchrony',    '>= 1.0.0'
  s.add_development_dependency 'excon',           '>= 0.27.5'
  s.add_development_dependency 'async-http',      '>= 0.48.0'
  s.add_development_dependency 'minitest',        '>= 5.0.0'
  s.add_development_dependency 'test-unit',       '>= 3.0.0'
  s.add_development_dependency 'rdoc',            '>  3.5.0'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
end
