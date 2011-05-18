#!/usr/bin/env rake

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "webmock"
    gem.summary = %Q{Library for stubbing HTTP requests in Ruby.}
    gem.description = %Q{WebMock allows stubbing HTTP requests and setting expectations on HTTP requests.}
    gem.email = "bartosz.blimke@gmail.com"
    gem.homepage = "http://github.com/bblimke/webmock"
    gem.authors = ["Bartosz Blimke"]
    gem.add_dependency "addressable", "~> 2.2", "> 2.2.5"
    gem.add_dependency "crack", ">=0.1.7"
    gem.add_development_dependency "rspec", ">= 2.0.0"
    gem.add_development_dependency "httpclient", ">= 2.1.5.2"
    gem.add_development_dependency "patron", ">= 0.4.9" unless RUBY_PLATFORM =~ /java/
    gem.add_development_dependency "em-http-request", ">= 0.2.14" unless RUBY_PLATFORM =~ /java/
    gem.add_development_dependency "curb", ">= 0.7.8" unless RUBY_PLATFORM =~ /java/
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

namespace :spec do
  desc 'Run specs against 1.8.6, REE, 1.8.7, 1.9.2 and jRuby'
  task :rubies do
    # JCF: I'd love to be able to use RVM's `rvm {rubies} specs` command but
    # the require tests in spec/other_net_http_libs_spec.rb break when doing
    # so.
    spec_files = Dir[File.dirname(__FILE__) + '/spec/**/*_spec.rb'].join(' ')
    sh "rvm 1.8.6@webmock,ree@webmock,1.8.7@webmock,1.9.2@webmock,jruby@webmock exec rspec #{spec_files}"
  end
end

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = ["-c", "-f progress", "-r ./spec/spec_helper.rb"]
  t.pattern = 'spec/**/*_spec.rb'
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.test_files = FileList["test/**/*.rb"].exclude("test/test_helper.rb")
  test.verbose = false
  test.warning = false
end

task :default => [:spec, :test]

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "webmock #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/webmock/webmock.rb')
end

