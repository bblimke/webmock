source 'http://rubygems.org/'

gemspec
if ENV["EM_HTTP_REQUEST_0_X"]
  gem 'em-http-request', '~> 0.3.0'
end

group :development do
  gem 'rake'
end

group :test do
  gem 'minitest_tu_shim', '1.3.2'
end

platforms :jruby do
  gem 'jruby-openssl'
end

if (RUBY_VERSION > '1.8.7' && (defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby")) ||
  (defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby")
  gem 'addressable', '>= 2.3.6'
else
  gem 'addressable', '< 2.4.0'
end
