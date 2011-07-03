source 'http://rubygems.org/'

gemspec

group :development do
  platforms :ruby do
    gem 'patron',          '0.4.9'
    gem 'em-http-request', '~> 0.3.0'
    gem 'curb',            '0.7.8'
    gem 'typhoeus',        '~> 0.2.1'
  end

  platforms :jruby do
    gem 'jruby-openssl', '~> 0.7'
  end
end

# Useful but not necessary
group :extras do
  gem 'guard-rspec', '>= 0.4.0'
  gem 'guard-cucumber', '>= 0.5.1'
  gem 'rb-fsevent', '>= 0.4.0'
  gem 'growl'

  gem 'yard'
  gem 'rdiscount'
  gem 'relish'
end
