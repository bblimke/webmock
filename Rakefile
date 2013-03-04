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
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ["-c", "-f progress", "-r ./spec/spec_helper.rb"]
  t.pattern = 'spec/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:spec_http_without_webmock) do |t|
  t.rspec_opts = ["-c", "-f progress", "-r ./spec/acceptance/net_http/real_net_http_spec.rb"]
  t.pattern = 'spec/acceptance/net_http/real_net_http_spec.rb'
end


task :em_http_request_0_x_spec do
  sh "EM_HTTP_REQUEST_0_X=true bundle install && EM_HTTP_REQUEST_0_X=true bundle exec rspec spec/acceptance/em_http_request/em_http_request_spec.rb" if RUBY_VERSION <= "1.8.7"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.test_files = FileList["test/**/*.rb"].exclude("test/test_helper.rb")
  test.verbose = false
  test.warning = false
end

Rake::TestTask.new(:minitest) do |test|
  test.test_files = FileList["minitest/**/*.rb"].exclude("test/test_helper.rb")
  test.verbose = false
  test.warning = false
end


task :default => [:spec, :spec_http_without_webmock, :test, :minitest]

task :require_ruby_18 do
  raise "This must be run on Ruby 1.8" unless RUBY_VERSION =~ /^1\.8/
end

task :release => [:require_ruby_18]
