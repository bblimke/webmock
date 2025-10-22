source 'https://rubygems.org/'

gemspec

# FIXME: This is a workaround to resolve the following error in Ruby 3.5:
#
# /home/runner/work/webmock/webmock/vendor/bundle/ruby/3.5.0+0/gems/ethon-0.16.0/lib/ethon.rb:2:
# warning: logger was loaded from the standard library, but is not part of the default gems starting from Ruby 3.5.0.
#
# It can likely be removed once `ethon`, which is a dependency of `typhoeus`, manages its `logger` dependency.
gem 'logger'
gem 'ostruct'
gem 'rake'

platforms :jruby do
  gem 'jruby-openssl'
  gem 'base64'
end
