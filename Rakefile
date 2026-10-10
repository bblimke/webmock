require 'bundler'
Bundler::GemHelper.install_tasks

def changelog_notes(version)
  File.read('CHANGELOG.md', encoding: 'UTF-8')[/^# #{Regexp.escape(version)}\n(.*?)(?=^# \d|\z)/m, 1].to_s.strip
end

namespace :release do
  task :changelog do
    version = Bundler::GemHelper.gemspec.version.to_s
    abort "CHANGELOG.md has no section for #{version}" if changelog_notes(version).empty?
  end

  desc 'Create the GitHub release for the current version, with notes from CHANGELOG.md'
  task :github do
    version = Bundler::GemHelper.gemspec.version.to_s
    sh 'gh', 'release', 'create', "v#{version}", '--title', version,
       '--notes', changelog_notes(version), '--verify-tag'
  end
end

# Make `rake release` check the changelog before anything is tagged or pushed,
# and create the GitHub release once the gem is on RubyGems.
task 'release:guard_clean' => 'release:changelog'
task 'release' => 'release:github'

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
  test.verbose = false
  test.warning = false
end

task default: [:spec, :spec_http_without_webmock, :test, :minitest]
