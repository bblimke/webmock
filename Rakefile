#!/usr/bin/env rake

require 'bundler'
Bundler::GemHelper.install_tasks

namespace :rvm do
  desc 'Run specs against 1.8.6, REE, 1.8.7, 1.9.2 and jRuby'
  task :specs do
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

require 'rdoc/task'
RDoc::Task.new do |rdoc|
  $:.push File.expand_path('../lib', __FILE__)
  require 'webmock/version'

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "webmock #{WebMock::VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/webmock/webmock.rb')
end
