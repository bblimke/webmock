source 'http://rubygems.org/'

gemspec
if ENV["EM_HTTP_REQUEST_0_X"]
  gem 'em-http-request', '~> 0.3.0'
end


group :development do
  gem 'rake'
  gem 'guard-rspec'
  gem 'rb-fsevent'
end

group :test do
  gem 'rack'
  gem 'minitest_tu_shim'
end

platforms :jruby do
  gem 'jruby-openssl'
end
