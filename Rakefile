require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "webmock"
    gem.summary = %Q{Library for stubbing HTTP requests in Ruby.}
    gem.description = %Q{WebMock allows stubbing HTTP requests and setting expectations on HTTP requests.}
    gem.email = "bartosz.blimke@gmail.com"
    gem.homepage = "http://github.com/bblimke/webmock"
    gem.authors = ["Bartosz Blimke"]
    gem.add_dependency "addressable", ">= 2.1.1"
    gem.add_dependency "crack", ">=0.1.7"
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_development_dependency "httpclient", ">= 2.1.5.2"
    gem.add_development_dependency "patron", ">= 0.4.5" unless RUBY_PLATFORM =~ /java/
    gem.add_development_dependency "em-http-request", ">= 0.2.7" unless RUBY_PLATFORM =~ /java/
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb'].exclude("spec/vendor")
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.test_files = FileList["test/**/*.rb"].exclude("test/test_helper.rb")
  test.verbose = false
  test.warning = false
end

task :spec => :check_dependencies

task :test => :check_dependencies

task :default => [:spec, :test]

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "webmock #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/webmock/webmock.rb')
end
