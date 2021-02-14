require 'bundler'
Bundler::GemHelper.install_tasks

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w[
    --force-color
    --format progress
    --require ./spec/spec_helper.rb
  ]
  t.pattern = 'spec/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:spec_http_without_webmock) do |t|
  t.rspec_opts = %w[
    --force-color
    --format progress
    --require ./spec/acceptance/net_http/real_net_http_spec.rb
  ]
  t.pattern = 'spec/acceptance/net_http/real_net_http_spec.rb'
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.test_files = FileList["test/**/*.rb"].exclude("test/test_helper.rb")
  test.options = "--use-color"
  test.verbose = false
  test.warning = false
end

Rake::TestTask.new(:minitest) do |test|
  test.test_files = FileList["minitest/**/*.rb"].exclude("test/test_helper.rb")
  test.options = "--pride"
  test.verbose = false
  test.warning = false
end

task default: [:spec, :spec_http_without_webmock, :test, :minitest]
