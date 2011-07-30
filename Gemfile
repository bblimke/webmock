source 'http://rubygems.org/'

gemspec

group :development do
  gem 'rake'
  gem 'guard-rspec'
  gem 'rb-fsevent'
end

group :test do
  gem 'sinatra' # for testing rack delegation
end

platforms :jruby do
  gem 'jruby-openssl', '~> 0.7'
end
