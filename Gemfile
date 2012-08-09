source 'http://rubygems.org/'

gemspec
if ENV["EM_HTTP_REQUEST_0_X"]
  gem 'em-http-request', '~> 0.3.0'
end

group :development do
  gem 'rake'
  gem 'guard-rspec', '~> 1.2'
end

# Appraisal does not support platforms.
#
# https://github.com/thoughtbot/appraisal/issues/21
gem 'jruby-openssl', '~> 0.7.7', platform: :jruby
