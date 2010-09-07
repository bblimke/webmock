#Changelog

## 1.3.5

* External requests can be disabled while allowing selected hosts. Thanks to Charles Li and Ryan Bigg

  This feature was available before only for localhost with `:allow_localhost => true`

		WebMock.disable_net_connect!(:allow => "www.example.org")

		Net::HTTP.get('www.something.com', '/')   # ===> Failure

		Net::HTTP.get('www.example.org', '/')      # ===> Allowed.

* Fixed Net::HTTP adapter so that it preserves the original behavior of Net::HTTP.

  When making a request with a block that calls #read_body on the request,
  Net::HTTP causes the body to be set to a Net::ReadAdapter, but WebMock was causing the body to be set to a string.

## 1.3.4

* Fixed Net::HTTP adapter to handle cases where a block with `read_body` call is passed to `request`.
  This fixes compatibility with `open-uri`. Thanks to Mark Evans for reporting the issue.

## 1.3.3

* Fixed handling of multiple values for the same response header for Net::HTTP. Thanks to Myron Marston for reporting the issue.

## 1.3.2

* Fixed compatibility with EM-HTTP-Request >= 0.2.9. Thanks to Myron Marston for reporting the issue.

## 1.3.1

* The less hacky way to get the stream behaviour working for em-http-request. Thanks to Martyn Loughran

* Fixed issues where Net::HTTP was not accepting valid nil response body. Thanks to Muness Alrubaie

## 1.3.0

* Added support for [em-http-request](http://github.com/igrigorik/em-http-request)

* Matching query params using a hash	 

	 	 stub_http_request(:get, "www.example.com").with(:query => {"a" => ["b", "c"]})
	 
	 	 RestClient.get("http://www.example.com/?a[]=b&a[]=c") # ===> Success
	 	 
	 	 request(:get, "www.example.com").with(:query => {"a" => ["b", "c"]}).should have_been_made  # ===> Success

* Matching request body against a hash. Body can be URL-Encoded, JSON or XML.

  (Thanks to Steve Tooke for the idea and a solution for url-encoded bodies)

		stub_http_request(:post, "www.example.com").
			with(:body => {:data => {:a => '1', :b => 'five'}})

		RestClient.post('www.example.com', "data[a]=1&data[b]=five", 
	  	:content_type => 'application/x-www-form-urlencoded')    # ===> Success
	
		RestClient.post('www.example.com', '{"data":{"a":"1","b":"five"}}', 
	  	:content_type => 'application/json')    # ===> Success
	
		RestClient.post('www.example.com', '<data a="1" b="five" />', 
			:content_type => 'application/xml' )    # ===> Success
			
		request(:post, "www.example.com").
    	with(:body => {:data => {:a => '1', :b => 'five'}},
    	 :headers => 'Content-Type' => 'application/json').should have_been_made	 # ===> Success

* Request callbacks (Thanks to Myron Marston for all suggestions)

    WebMock can now invoke callbacks for stubbed or real requests:

		WebMock.after_request do |request_signature, response|
		  puts "Request #{request_signature} was made and #{response} was returned"
		end
    
    invoke callbacks for real requests only and except requests made with Patron client

		WebMock.after_request(:except => [:patron], :real_requests_only => true)  do |request_signature, response|
		  puts "Request #{request_signature} was made and #{response} was returned"
		end

* `to_raise()` now accepts an exception instance or a string as argument in addition to an exception class

		stub_request(:any, 'www.example.net').to_raise(StandardError.new("some error"))
    
		stub_request(:any, 'www.example.net').to_raise("some error")

* Matching requests based on a URI is 30% faster

* Fixed constant namespace issues in HTTPClient adapter. Thanks to Nathaniel Bibler for submitting a patch.

## 1.2.2

* Fixed problem where ArgumentError was raised if query params were made up of an array e.g. data[]=a&data[]=b. Thanks to Steve Tooke

## 1.2.1

* Changed license from GPL to MIT

* Fixed gemspec file. Thanks to Razic

## 1.2.0 

* RSpec 2 compatibility. Thanks to Sam Phillips!

* :allow_localhost => true' now permits 127.0.0.1 as well as 'localhost'. Thanks to Mack Earnhardt

* Request URI matching in now 2x faster!


## 1.1.0

* [VCR](http://github.com/myronmarston/vcr/) compatibility. Many thanks to Myron Marston for all suggestions.
	
* Support for stubbing requests and returning responses with multiple headers with the same name. i.e multiple Accept headers.	

		stub_http_request(:get, 'www.example.com').
		  with(:headers => {'Accept' => ['image/png', 'image/jpeg']}).
		  to_return(:body => 'abc')
		RestClient.get('www.example.com',
		 {"Accept" => ['image/png', 'image/jpeg']}) # ===> "abc\n"	

* When real net connections are disabled and unstubbed request is made, WebMock throws WebMock::NetConnectNotAllowedError instead of assertion error or StandardError.

* Added WebMock.version()


## 1.0.0

* Added support for [Patron](http://toland.github.com/patron/)

* Responses dynamically evaluated from block (idea and implementation by Tom Ward)

		stub_request(:any, 'www.example.net').
		     to_return { |request| {:body => request.body} }

		RestClient.post('www.example.net', 'abc')    # ===> "abc\n"

* Responses dynamically evaluated from lambda (idea and implementation by Tom Ward)

    	stub_request(:any, 'www.example.net').
	      to_return(lambda { |request| {:body => request.body} })

	    RestClient.post('www.example.net', 'abc')    # ===> "abc\n"	       

* Response with custom status message 

		stub_request(:any, "www.example.com").to_return(:status => [500, "Internal Server Error"])

		req = Net::HTTP::Get.new("/")
		Net::HTTP.start("www.example.com") { |http| http.request(req) }.message # ===> "Internal Server Error"

* Raising timeout errors (suggested by Jeffrey Jones) (compatibility with Ruby 1.8.6 by Mack Earnhardt)

		stub_request(:any, 'www.example.net').to_timeout

		RestClient.post('www.example.net', 'abc')    # ===> RestClient::RequestTimeout

* External requests can be disabled while allowing localhost (idea and implementation by Mack Earnhardt)

		WebMock.disable_net_connect!(:allow_localhost => true)

		Net::HTTP.get('www.something.com', '/')   # ===> Failure

		Net::HTTP.get('localhost:9887', '/')      # ===> Allowed. Perhaps to Selenium?


### Bug fixes

* Fixed issue where Net::HTTP adapter didn't work for requests with body responding to read (reported by Tekin Suleyman)
* Fixed issue where request stub with headers declared as nil was matching requests with non empty headers

## 0.9.1

* Fixed issue where response status code was not read from raw (curl -is) responses

## 0.9.0
  
* Matching requests against provided block (by Sergio Gil)

		stub_request(:post, "www.example.com").with { |request| request.body == "abc" }.to_return(:body => "def")
		RestClient.post('www.example.com', 'abc')    # ===> "def\n"
		request(:post, "www.example.com").with { |req| req.body == "abc" }.should have_been_made	
		#or 
		assert_requested(:post, "www.example.com") { |req| req.body == "abc" }

* Matching request body against regular expressions (suggested by Ben Pickles)

		stub_request(:post, "www.example.com").with(:body => /^.*world$/).to_return(:body => "abc")
		RestClient.post('www.example.com', 'hello world')    # ===> "abc\n"
	
* Matching request headers against regular expressions (suggested by Ben Pickles)

		stub_request(:post, "www.example.com").with(:headers => {"Content-Type" => /image\/.+/}).to_return(:body => "abc")
		RestClient.post('www.example.com', '', {'Content-Type' => 'image/png'})    # ===> "abc\n"

* Replaying raw responses recorded with `curl -is`

		`curl -is www.example.com > /tmp/example_curl_-is_output.txt`
		raw_response_file = File.new("/tmp/example_curl_-is_output.txt")
	
	from file
	
		stub_request(:get, "www.example.com").to_return(raw_response_file)

	or string
	
		stub_request(:get, "www.example.com").to_return(raw_response_file.read)

* Multiple responses for repeated requests

		stub_request(:get, "www.example.com").to_return({:body => "abc"}, {:body => "def"})
		Net::HTTP.get('www.example.com', '/')    # ===> "abc\n"
		Net::HTTP.get('www.example.com', '/')    # ===> "def\n"

* Multiple responses using chained `to_return()` or `to_raise()` declarations

		stub_request(:get, "www.example.com").
			to_return({:body => "abc"}).then.  #then() just is a syntactic sugar
			to_return({:body => "def"}).then.
			to_raise(MyException)
		Net::HTTP.get('www.example.com', '/')    # ===> "abc\n"
		Net::HTTP.get('www.example.com', '/')    # ===> "def\n"
		Net::HTTP.get('www.example.com', '/')    # ===> MyException raised
	
* Specifying number of times given response should be returned

		stub_request(:get, "www.example.com").
			to_return({:body => "abc"}).times(2).then.
			to_return({:body => "def"})
	
		Net::HTTP.get('www.example.com', '/')    # ===> "abc\n"
		Net::HTTP.get('www.example.com', '/')    # ===> "abc\n"
		Net::HTTP.get('www.example.com', '/')    # ===> "def\n"
	
* Added support for `Net::HTTP::Post#body_stream`

	This fixes compatibility with new versions of RestClient
	
* WebMock doesn't suppress default request headers added by http clients anymore.

	i.e. Net::HTTP adds `'Accept'=>'*/*'` to all requests by default
	
	
	
## 0.8.2
  
  * Fixed issue where WebMock was not closing IO object passed as response body after reading it.
  * Ruby 1.9.2 compat: Use `File#expand_path` for require path because "." is not be included in LOAD_PATH since Ruby 1.9.2


## 0.8.1
  
  * Fixed HTTPClient adapter compatibility with Ruby 1.8.6 (reported by Piotr Usewicz)
  * Net:HTTP adapter now handles request body assigned as Net::HTTP::Post#body attribute (fixed by Mack Earnhardt)
  * Fixed issue where requests were not matching stubs with Accept header set.(reported by Piotr Usewicz)
  * Fixed compatibility with Ruby 1.9.1, 1.9.2 and JRuby 1.3.1 (reported by Diego E. “Flameeyes” Pettenò)
  * Fixed issue with response body declared as IO object and multiple requests (reported by Niels Meersschaert)
  * Fixed "undefined method `assertion_failure'" error (reported by Nick Plante)


## 0.8.0

  * Support for HTTPClient (sync and async requests)
  * Support for dynamic responses. Response body and headers can be now declared as lambda. 
	(Thanks to Ivan Vega ( @ivanyv ) for suggesting this feature)
  * Support for stubbing and expecting requests with empty body
  * Executing non-stubbed request leads to failed expectation instead of error


### Bug fixes

  * Basic authentication now works correctly
  * Fixed problem where WebMock didn't call a block with the response when block was provided
  * Fixed problem where uris with single slash were not matching uris without path provided


## 0.7.3

  * Clarified documentation
  * Fixed some issues with loading of Webmock classes
  * Test::Unit and RSpec adapters have to be required separately


## 0.7.2

  * Added support for matching escaped and non escaped URLs
