source 'http://rubygems.org/'

gemspec
if ENV["EM_HTTP_REQUEST_0_X"]
  gem 'em-http-request', '~> 0.3.0'
end

group :development, :test do
  gem "pry"
end

group :development do
  gem 'rake'
end

group :test do
  gem 'rack'
  gem 'minitest_tu_shim', '1.3.2'
end

platforms :jruby do
  gem 'jruby-openssl'
end
