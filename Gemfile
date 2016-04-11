source 'http://rubygems.org/'

gemspec
if ENV["EM_HTTP_REQUEST_0_X"]
  gem 'em-http-request', '~> 0.3.0'
end

group :development do
  gem 'rake', '~> 10.5.0' if RUBY_VERSION < '1.9.3'
  gem 'rake' if RUBY_VERSION >= '1.9.3'
end

group :test do
  gem 'minitest_tu_shim', '1.3.2'
end

platforms :jruby do
  gem 'jruby-openssl'
end
