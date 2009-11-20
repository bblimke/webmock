WebMock
=======

Library for stubbing HTTP requests in Ruby.

Features
--------

* Stubbing requests and setting requests expectations
* Matching requests based on method, url, headers and body
* Support for Test::Unit and RSpec (and can be easily extended to other frameworks)
* Support for Net::Http and other http libraries based on Net::Http
* Adding other http library adapters is easy


Installation
------------

    gem install webmock --source http://gemcutter.org

In your `test/test_helper.rb` or `spec/spec_helper.rb` include the following lines

    require 'webmock'
	
	include WebMock

Now you are ready to write your tests/specs with stubbed HTTP calls. 

## Examples

### Stubbed request based on url only and with the default response

	 stub_request(:any, "www.google.com")

	 Net::HTTP.get('www.google.com', '/')    # ===> Success
	
### Stubbing requests based on method, url, body and headers

	stub_request(:post, "www.google.com").with(:body => "abc", :headers => { 'Content-Length' => 3 })

	url = URI.parse('http://www.google.com/')
    req = Net::HTTP::Post.new(url.path)
	req['Content-Length'] = 3
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req, 'abc')
    }    # ===> Success

### Matching custom request headers

    stub_request(:any, "www.google.com").with(:headers=>{'Header-Name'=>"Header-Value"}).to_return(:body => "abc", :status => 200)

	url = URI.parse('http://www.google.com/')
    req = Net::HTTP::Post.new(url.path)
	req['Header-Name'] = "Header-Value"
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req, 'abc')
    }    # ===> Success

### Custom response

	stub_request(:any, "www.google.com").to_return(:body => "abc", :status => 200,  :headers => { 'Content-Length' => 3 })
	
	Net::HTTP.get('www.google.com', '/')    # ===> "abc"
	
### Custom response with body as file path

	File.open('/tmp/response_body.txt', 'w') { |f| f.puts 'abc' }

	stub_request(:any, "www.google.com").to_return(:body => "/tmp/response_body.txt", :status => 200)

	Net::HTTP.get('www.google.com', '/')    # ===> "abc\n"
	
### Request with basic authentication

	stub_request(:any, "john:smith@www.google.com")
	
	Net::HTTP.get(URI.parse('http://john:smith@www.google.com'))    # ===> Success
	
### Matching urls using regular expressions

	 stub_request(:any, /.*google.*/)

	 Net::HTTP.get('www.google.com', '/') # ===> Success

### Real requests to network can be allowed or disabled

	WebMock.allow_net_connect!

	stub_request(:any, "www.google.com").to_return(:body => "abc")

	Net::HTTP.get('www.google.com', '/')    # ===> "abc"
	
	Net::HTTP.get('www.something.com', '/') # ===> /.+Something.+/
	
	WebMock.disable_net_connect!
	
	Net::HTTP.get('www.something.com', '/')    # ===> Failure

### Clearing stubs

	stub_request(:any, "www.google.com")

	Net::HTTP.get('www.google.com', '/')    # ===> Success
	
	reset_webmock
	
	Net::HTTP.get('www.google.com', '/')    # ===> Failure


### Test/Unit style assertions (they actually work everywhere, in RSpec too)

    stub_request(:any, "www.google.com")

	url = URI.parse('http://www.google.com/')
    req = Net::HTTP::Post.new(url.path)
	req['Content-Length'] = 3
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req, 'abc')
    }

	assert_requested :post, "http://www.google.com", :headers => {'Content-Length' => 3}, :body => "abc", :times => 1    # ===> Success
	
	assert_not_requested :get, "http://www.something.com"    # ===> Success

### Expecting real (not stubbed) requests

	WebMock.allow_net_connect!
	
	Net::HTTP.get('www.google.com', '/')    # ===> Success

	assert_requested :get, "http://www.google.com"    # ===> Success

### RSpec matchers 1

	request(:post, "www.google.com").with(:body => "abc", :headers => {'Content-Length' => 3}).should have_been_made.once
	
	request(:post, "www.something.com").should have_been_made.times(3)
	
	request(:any, "www.example.com").should_not have_been_made

### RSpec matchers 2 ([fakeweb-matcher](http://github.com/freelancing-god/fakeweb-matcher) style)

	WebMock.should have_requested(:get, "www.google.com").with(:body => "abc", :headers => {'Content-Length' => 3}).twice
	
	WebMock.should_not have_requested(:get, "www.something.com")

Notes
-----

### Matching requests

Here are the criteria of matching requests:

* request url matches stubbed request url pattern
* and request method is the same as stubbed request method or stubbed request method is :any
* and request body is the same as stubbed request body or stubbed request body is not set (is nil)
* and request headers are the same as stubbed request headers or stubbed request headers are a subset of request headers or stubbed request headers are not set

### Precedence of stubs

Always the last declared stub matching the request will be applied. 
i.e

	stub_request(:get, "www.google.com").to_return(:body => "abc")
	stub_request(:get, "www.google.com").to_return(:body => "def")

	Net::HTTP.get('www.google.com', '/')   # ====> "def"

Bugs and Issues
---------------

Please submit them here [http://github.com/bblimke/webmock/issues](http://github.com/bblimke/webmock/issues)

Suggestions
------------

If you have any suggestions on how to improve WebMock please send an email to the mailing list [groups.google.com/group/webmock-users](http://groups.google.com/group/webmock-users)

I'm particularly interested in how the DSL could be improved.

Todo
----

* Add EventMachine::Protocols::HttpClient adapter

Credits
-------

Thank you Fakeweb! This library is based on the idea taken from [FakeWeb](fakeweb.rubyforge.org).
I took couple of solutions from that project. I also copied some code i.e Net:Http adapter or url normalisation function. 
Fakeweb architecture unfortunately didn't allow me to extend it easily with the features I needed.
I also preferred some things to work differently i.e request stub precedence.

Copyright
---------

Copyright 2009 Bartosz Blimke. See LICENSE for details.
