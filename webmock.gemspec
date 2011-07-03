# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'web_mock/version'

Gem::Specification.new do |s|
  s.name        = 'webmock'
  s.version     = WebMock::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Bartosz Blimke', 'James Conroy-Finn']
  s.email       = ['bartosz.blimke@gmail.com', 'james@logi.cl']
  # TODO JCF: Change homepage to http://webmock.github.com
  s.homepage    = 'http://github.com/bblimke/webmock'
  s.summary     = %q{Library for stubbing HTTP requests in Ruby.}
  s.description = %q{WebMock allows stubbing HTTP requests and setting expectations on HTTP requests.}

  s.add_dependency 'addressable', '~> 2.2', '> 2.2.5'
  s.add_dependency 'crack', '>=0.1.7'
  s.add_dependency 'mixology', '~> 0.2.0'

  {
    'bundler'         => '~> 1.0.7',
    'rake'            => '~> 0.9.2',

    'patron'          => '0.4.9',
    'em-http-request' => '~> 0.3.0',
    'curb'            => '0.7.8',
    'httpclient'      => '>= 2.1.5.2',
    'typhoeus'        => '~> 0.2.1',

    'rspec'           => '~> 2.6',
    'cucumber'        => '~> 1.0',
    'aruba'           => '~> 0.4',

    'timecop'         => '~> 0.3.5',
    'rack'            => '1.1.0',
    'sinatra'         => '~> 1.1.0'
  }.each do |lib, version|
    s.add_development_dependency lib, version
  end

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
end
