WebMock
=======

Library for stubbing HTTP requests and setting expectations on HTTP requests in Ruby.

Features
--------

* Stubbing HTTP requests at low Net::HTTP level (no need to change tests when you change HTTP lib interface)
* Setting and verifying expectations on HTTP requests
* Matching requests based on method, URI, headers and body
* Smart matching of the same URIs in different representations (also encoded and non encoded forms)
* Smart matching of the same headers in different representations.
* Support for Test::Unit and RSpec (and can be easily extended to other frameworks)
* Support for Net::HTTP and other http libraries based on Net::HTTP (i.e RightHttpConnection, rest-client, HTTParty)
* Support for HTTPClient library (both sync and async requests)
* Easy to extend to other HTTP libraries except Net::HTTP

Installation
------------

    gem install webmock --source http://gemcutter.org

In your `test/test_helper.rb` add these two lines:

    require 'webmock/test_unit'
	
	include WebMock

or if you use RSpec add these lines to `spec/spec_helper`:

	require 'webmock/rspec'

	include WebMock

You can also use WebMock without RSpec or Test::Unit support:

	require 'webmock'

	include WebMock

## Examples



## Stubbing


### Stubbed request based on uri only and with the default response

	 stub_request(:any, "www.example.com")

	 Net::HTTP.get("www.example.com", "/")    # ===> Success

### Stubbing requests based on method, uri, body and headers

	stub_request(:post, "www.example.com").with(:body => "abc", :headers => { 'Content-Length' => 3 })

	uri = URI.parse("http://www.example.com/")
    req = Net::HTTP::Post.new(uri.path)
	req['Content-Length'] = 3
    res = Net::HTTP.start(uri.host, uri.port) {|http|
      http.request(req, "abc")
    }    # ===> Success

### Matching custom request headers

    stub_request(:any, "www.example.com").
	  with( :headers=>{ 'Header-Name' => 'Header-Value' } ).to_return(:body => "abc", :status => 200)

	uri = URI.parse('http://www.example.com/')
    req = Net::HTTP::Post.new(uri.path)
	req['Header-Name'] = 'Header-Value'
    res = Net::HTTP.start(uri.host, uri.port) {|http|
      http.request(req, 'abc')
    }    # ===> Success

### Stubbing with custom response

	stub_request(:any, "www.example.com").to_return(:body => "abc", :status => 200,  :headers => { 'Content-Length' => 3 } )
	
	Net::HTTP.get("www.example.com", '/')    # ===> "abc"

### Custom response with body specified as IO object

	File.open('/tmp/response_body.txt', 'w') { |f| f.puts 'abc' }

	stub_request(:any, "www.example.com").to_return(:body => File.new('/tmp/response_body.txt'), :status => 200)

	Net::HTTP.get('www.example.com', '/')    # ===> "abc\n"

### Custom response with dynamically evaluated response
	
    stub_request(:any, 'www.example.net').
      to_return(:body => lambda { |request| request.body })

    RestClient.post('www.example.net', 'abc')    # ===> "abc\n"	

### Request with basic authentication

    stub_request(:get, "user:pass@www.example.com")

    Net::HTTP.start('www.example.com') {|http|
      req = Net::HTTP::Get.new('/')
      req.basic_auth 'user', 'pass'
      http.request(req)
    }  # ===> Success

### Matching uris using regular expressions

	 stub_request(:any, /.*example.*/)

	 Net::HTTP.get('www.example.com', '/') # ===> Success

### Real requests to network can be allowed or disabled

	WebMock.allow_net_connect!

	stub_request(:any, "www.example.com").to_return(:body => "abc")

	Net::HTTP.get('www.example.com', '/')    # ===> "abc"
	
	Net::HTTP.get('www.something.com', '/') # ===> /.+Something.+/
	
	WebMock.disable_net_connect!
	
	Net::HTTP.get('www.something.com', '/')    # ===> Failure


## Setting Expectations

### Setting expectations in Test::Unit
	require 'webmock/test_unit'

    stub_request(:any, "www.example.com")

	uri = URI.parse('http://www.example.com/')
    req = Net::HTTP::Post.new(uri.path)
	req['Content-Length'] = 3
    res = Net::HTTP.start(uri.host, uri.port) {|http|
      http.request(req, 'abc')
    }

	assert_requested :post, "http://www.example.com",
	  :headers => {'Content-Length' => 3}, :body => "abc", :times => 1    # ===> Success
	
	assert_not_requested :get, "http://www.something.com"    # ===> Success

### Expecting real (not stubbed) requests

	WebMock.allow_net_connect!
	
	Net::HTTP.get('www.example.com', '/')    # ===> Success

	assert_requested :get, "http://www.example.com"    # ===> Success


### Setting expectations in RSpec
 This style is borrowed from [fakeweb-matcher](http://github.com/freelancing-god/fakeweb-matcher)

	require 'webmock/rspec'

	WebMock.should have_requested(:get, "www.example.com").with(:body => "abc", :headers => {'Content-Length' => 3}).twice
	
	WebMock.should_not have_requested(:get, "www.something.com")

### Different way of setting expectations in RSpec

	request(:post, "www.example.com").with(:body => "abc", :headers => {'Content-Length' => 3}).should have_been_made.once

	request(:post, "www.something.com").should have_been_made.times(3)

	request(:any, "www.example.com").should_not have_been_made


## Clearing stubs and request history

If you want to reset all current stubs and history of requests use `WebMock.reset_webmock`

	stub_request(:any, "www.example.com")

	Net::HTTP.get('www.example.com', '/')    # ===> Success

	reset_webmock

	Net::HTTP.get('www.example.com', '/')    # ===> Failure

	assert_not_requested :get, "www.example.com"    # ===> Success


## Matching requests

An executed request matches stubbed request if it passes following criteria:

  When request URI matches stubbed request URI string or Regexp pattern<br/>
  And request method is the same as stubbed request method or stubbed request method is :any<br/>
  And request body is the same as stubbed request body or stubbed request body is not specified<br/>
  And request headers match stubbed request headers, or stubbed request headers match a subset of request headers, or stubbed request headers are not specified

## Precedence of stubs

Always the last declared stub matching the request will be applied i.e:

	stub_request(:get, "www.example.com").to_return(:body => "abc")
	stub_request(:get, "www.example.com").to_return(:body => "def")

	Net::HTTP.get('www.example.com', '/')   # ====> "def"

## Matching URIs

WebMock will match all different representations of the same URI. 

I.e all the following representations of the URI are equal:

    "www.example.com"
    "www.example.com/"
    "www.example.com:80"
    "www.example.com:80/"
    "http://www.example.com"
    "http://www.example.com/"
    "http://www.example.com:80"
    "http://www.example.com:80/"
	
The following URIs with basic authentication are also equal for WebMock

	"a b:pass@www.example.com"
	"a b:pass@www.example.com/"
	"a b:pass@www.example.com:80"
	"a b:pass@www.example.com:80/"
	"http://a b:pass@www.example.com"
	"http://a b:pass@www.example.com/"
	"http://a b:pass@www.example.com:80"
	"http://a b:pass@www.example.com:80/"
	"a%20b:pass@www.example.com"
	"a%20b:pass@www.example.com/"
	"a%20b:pass@www.example.com:80"
	"a%20b:pass@www.example.com:80/"
	"http://a%20b:pass@www.example.com"
	"http://a%20b:pass@www.example.com/"
	"http://a%20b:pass@www.example.com:80"
	"http://a%20b:pass@www.example.com:80/"	

or these

	"www.example.com/big image.jpg/?a=big image&b=c"
	"www.example.com/big%20image.jpg/?a=big%20image&b=c"
	"www.example.com:80/big image.jpg/?a=big image&b=c"
	"www.example.com:80/big%20image.jpg/?a=big%20image&b=c"
	"http://www.example.com/big image.jpg/?a=big image&b=c"
	"http://www.example.com/big%20image.jpg/?a=big%20image&b=c"
	"http://www.example.com:80/big image.jpg/?a=big image&b=c"
	"http://www.example.com:80/big%20image.jpg/?a=big%20image&b=c"


If you provide Regexp to match URI, WebMock will try to match it against every valid form of the same url.

I.e `/.*big image.*/` will match `www.example.com/big%20image.jpg` because it is equivalent of `www.example.com/big image.jpg`


## Matching headers

WebMock will match request headers against stubbed request headers in the following situations:

1. Stubbed request has headers specified and request headers are the same as stubbed headers <br/>
i.e stubbed headers: `{ 'Header1' => 'Value1', 'Header1' => 'Value1' }`, requested: `{ 'Header1' => 'Value1', 'Header1' => 'Value1' }`

2. Stubbed request has headers specified and stubbed request headers are a subset of request headers <br/>
i.e stubbed headers: `{ 'Header1' => 'Value1'  }`, requested: `{ 'Header1' => 'Value1', 'Header1' => 'Value1' }`

3. Stubbed request has no headers <br/>
i.e stubbed headers: `nil`, requested: `{ 'Header1' => 'Value1', 'Header1' => 'Value1' }`

WebMock normalises headers and treats all forms of same headers as equal:
i.e the following two sets of headers are equal:

`{ "Header1" => "value1", :content_length => 123, :X_CuStOm_hEAder => :value }`

`{ :header1 => "value1",  "Content-Length" => 123, "x-cuSTOM-HeAder" => "value" }`


## Bugs and Issues

Please submit them here [http://github.com/bblimke/webmock/issues](http://github.com/bblimke/webmock/issues)

## Suggestions

If you have any suggestions on how to improve WebMock please send an email to the mailing list [groups.google.com/group/webmock-users](http://groups.google.com/group/webmock-users)

I'm particularly interested in how the DSL could be improved.

## Credits

Thanks to my fellow [Bambinos](http://new-bamboo.co.uk/) for all the great suggestions!

Thank you Fakeweb! This library was inspired by [FakeWeb](fakeweb.rubyforge.org).
I took couple of solutions from that project. I also copied some code i.e Net:HTTP adapter. 
Fakeweb architecture unfortunately didn't allow me to extend it easily with the features I needed.
I also preferred some things to work differently i.e request stub precedence.

## Copyright

Copyright 2009 Bartosz Blimke. See LICENSE for details.
