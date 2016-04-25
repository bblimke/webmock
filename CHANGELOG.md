# Changelog

## 1.24.6

  * Fixed issue with RUBY_VERSION comparison using old RubyGems.

    Thanks to [Chris Griego](https://github.com/cgriego).

  * Support for http.rb >= 2.0.0

## 1.24.4

  * Fixed the issue with parsing query to a hash with nested array i.e. `a[][b][]=one&a[][c][]=two`

    Thanks to [Tim Diggins](https://github.com/timdiggins) for reporting the issue.
    Thanks to [Cedric Pimenta](https://github.com/cedricpim) for finding the solution.

## 1.24.3

  * Allow Net:HTTP headers keys to be provided as symbols if `RUBY_VERSION` >= 2.3.0

    Thanks to [Alex Kestner](https://github.com/akestner)

  * Added a clear message on an attept to match a multipart encoded request body.
    WebMock does't support requests with multipart body... yet.

  * `WebMock.disable_net_connect` `:allow` option, provided as regexp, matches https URIs correctly.

  * `WebMock.disable_net_connect` `:allow` option can be set as a url string with scheme, host and port.

        WebMock.disable_net_connect!(:allow => 'https://www.google.pl')

    Thanks to [Gabriel Chaney](https://github.com/gabrieljoelc) for reporting the issue.


## 1.24.2

  * Improve parsing of params on request

    Thanks to [Cedric Pimenta](https://github.com/cedricpim)

## 1.24.1

  * HTTPClient adapter supports reading basic authentication credentials directly from Authorization header.

    Thanks to [Michiel Karnebeek](https://github.com/mkarnebeek)

## 1.24.0

  * Enabled support for Curb > 0.8.6

## 1.23.0

  * `WebMock.disable_net_connect` accepts `:allow` option with an object that responds to `#call`, receiving a `URI` object and returning a boolean:


        blacklist = ['google.com', 'facebook.com', 'apple.com']
        allowed_sites = lambda{|uri|
          blacklist.none?{|site| uri.host.include?(site) }
        }
        WebMock.disable_net_connect!(:allow => allowed_sites)

        RestClient.get('www.example.org', '/')  # ===> Allowed
        RestClient.get('www.facebook.com', '/') # ===> Failure
        RestClient.get('apple.com', '/')        # ===> Failure

    Thanks to [Pablo Brasero](https://github.com/pablobm)

  * Support for HTTPClient stream responses with body chunks

    Thanks to [Cedric Pimenta](https://github.com/cedricpim)


## 1.22.6

  * Fixes [issue](https://github.com/bblimke/webmock/issues/568) around
    WebMock restricting [Addressable](https://github.com/sporkmonger/addressable)
    version, based on Ruby 1.8.7 for all versions of Ruby.

    This change inverts that, and forces Ruby 1.8.7 users to specify in thier
    Gemfile an Addressable version < 2.4.0.

    Thanks to [PikachuEXE](https://github.com/PikachuEXE) and
    [Matthew Rudy Jacobs](https://github.com/matthewrudy).

## 1.22.5

  * Fixes [bug](https://github.com/bblimke/webmock/issues/565) where WebMock tries
    to alias a method that is deprecated in Ruby Versions > 1.9.2 ('sysread' for class 'StringIO')

    Thanks to [Marcos Acosta](https://github.com/mmaa) for discovering this bug.

## 1.22.4

  * Adds support for JSONClient (a subclass of HTTPClient)

    Thanks to [Andrew Kozin](https://github.com/nepalez)

  * Adds support for Ruby 2.3.0

    Thanks to [Charles Pence](https://github.com/cpence)

  * Adds support for [http](https://github.com/httprb/http) versions >= 1.0.0

    Thanks to [Alexey Zapparov](https://github.com/ixti)

  * Fixes support for Ruby 1.8.7 by restrciting Addressable version < 2.4.0

    Thanks to [Matthew Rudy Jacobs](https://github.com/matthewrudy)

## 1.22.3

  * Return "effective_url" attribute in Typhoeus::Response

    Thanks to [Senya](https://github.com/cmrd-senya)

## 1.22.2

  * Fix: prevents adding an extra =true to urls with parameters without values

    Thanks to [David Begin](https://github.com/davidbegin)

## 1.22.1

  * Adds Rack as a development dependency and removes require rack/utils in main lib.

    Thanks to [Keenan Brock](https://github.com/kbrock)

## 1.22.0

  All the credit for preparing this release go to [David Begin](https://github.com/davidbegin)!

  * Adds [Manticore](https://github.com/cheald/manticore) support.

      Thanks to [Mike Knepper](https://github.com/mikeknep), [David Abdemoulaie](https://github.com/hobodave)

  * Update to Show a hash diff for requests that have stubs with a body.

      Thanks to [yurivm](https://github.com/yurivm)

  * Update to mirror Net::HTTP handling of headers as symbols

  * Update to ignore non-comparable-values error when sorting
    query values, because sorting is just a convience.

      Thanks to [Magne Land](https://github.com/magneland)

  * Covert Boolean values to Strings when using them to define
    the body of a request.

      Thanks to [Krzysztof Rygielski](https://github.com/riggy)

  * Fixes WebMock's parsing Multibyte characters

      Thanks to [Zhao Wen](https://github.com/VincentZhao)

  * Updates to be compatible with httpclient 2.6.0

  * Converts keys from symbols to strings when for QueryMapper.to_query

      Thanks to [Ramon Tayag](https://github.com/ramontayag)

  * Restricts http.rb version to 0.7.3 for Ruby 1.8.7

  * Fixes issue emulating em-http-request's handling of multiple requests.

      Thanks to [Matt Palmer](https://github.com/mpalmer)

  * WebMock requires only the necessary parts of crack to avoid pulling in safe_yaml

      Thanks to [Johannes Schlumberger](https://github.com/spjsschl)

## 1.21.0

  * Support for http.rb >= 0.8.0

      Thanks to [Zachary Anker](https://github.com/zanker), [Aleksey V. Zapparov](https://github.com/ixti)

  * Support for http.rb 0.7.0

      Thanks to [Mattias Putman](https://github.com/challengee)

  * Added support for RSpec3-like `and_return`, `and_raise`, `and_timeout` syntax.

      Thanks to [Franky Wahl](https://github.com/frankywahl)

  * Restricted Curb support up to version 0.8.6. WebMock specs fail with Curb 0.8.7.

## 1.20.4

  * Fixed support for `hash_including` matcher in RSpec 3

## 1.20.3

  * `with` method raises error if provided without options hash and without block

  * `with` and `to_return` raise an error if invoked with invalid keys in options hash.

## 1.20.2

  * WebMock provides a helpful error message if an incompatible object is given as response body.

      Thanks to [Mark Lorenz](https://github.com/dapplebeforedawn)

## 1.20.1

  * `assert_requested` and `assert_not_requested` accept `at_least_times` and `at_most_times` options

      Thanks to [Dan Buettner](https://github.com/Capncavedan)

  * Silenced `instance variable undefined` warnings in Curb adapted.

      Thanks to [Sven Riedel](https://github.com/sriedel)

## 1.20.0

  * Add support for on_missing callback of Curb::Easy

      Thanks to [Tasos Stathopoulos](https://github.com/astathopoulos)

  * Add at_least_times and at_most_times matchers

      Thanks to [Dan Buettner](https://github.com/Capncavedan)

## 1.19.0

  * Fixed issue with Excon adapter giving warning message when redirects middleware was enabled.

      Thanks to [Theo Hultberg](https://github.com/iconara) for reporting that.

  * Fixed issue with `undefined method 'valid_request_keys' for Excon::Utils:Module`

      Thanks to [Pablo Jairala](https://github.com/davidjairala)

  * Fixed query mapper to encode `'one' => ['1','2']` as `'one[]=1&one[]=2'`.

      Thanks to [Insoo Buzz Jung](https://github.com/insoul)

  * Improved cookies support for em-http-request

      Thanks to [Carlos Alonso Pérez](https://github.com/calonso)

  * Fix HTTP Gem adapter to ensure uri attribute is set on response object.

      Thanks to [Aleksey V. Zapparov](https://github.com/ixti)

  * Fixed HTTPClient adapter. The response header now receives `request_method`, `request_uri`, and `request_query` transferred from request header

      Thanks to [trlorenz](https://github.com/trlorenz)

  * Query mapper supports nested data structures i.e. `{"first" => [{"two" => [{"three" => "four"}, "five"]}]}`

      Thanks to [Alexander Simonov](https://github.com/simonoff)

  * Fixed compatibility with latest versions of Excon which don't define `VALID_REQUEST_KEYS` anymore.

      Thanks to [Pablo Jairala](https://github.com/davidjairala)

  * Request method is always a symbol is request signatures. This fixes the issue of WebMock not matching Typhoeus requests with request method defined as string.

      Thanks to [Thorbjørn Hermanse](https://github.com/thhermansen)

  * Stubbing instructions which are displayed when no matching stub is found, can be disabled with `Config.instance.show_stubbing_instructions = false`

      Thanks to [Mark Lorenz](https://github.com/dapplebeforedawn)

  * Notation used for mapping query strings to data structure can be configured i.e. `WebMock::Config.instance.query_values_notation = :subscript`. This allows setting `:flat_array` notation which supports duplicated parameter names in query string.

      Thanks to [tjsousa](https://github.com/tjsousa)

## 1.18.0

* Updated dependency on Addressable to versions >= 2.3.6

* Added support for matching uris using RFC 6570 (URI Templates)

        uri_template = Addressable::Template.new "www.example.com/{id}/"
        stub_request(:any, uri_template)

  Thanks to [Max Lincoln](https://github.com/maxlinc)

* Fixed content length calculation for Rack responses with UTF8 body

  Thanks to [Oleg Gritsenko](https://github.com/Claster)

* Add missing Curl::Easy aliases

  Thanks to [Hwan-Joon Choi](https://github.com/hc5duke)

* HTTP Gem >= 0.6.0 compatibility

  Thanks to [Aleksey V. Zapparov](https://github.com/ixti)

* Minitest 4 and 5 compatibility.

  Thanks to [SHIBATA Hiroshi](https://github.com/hsbt)

## 1.17.4

* Update matchers for RSpec 3's matcher protocol

  Thanks to [Rob Olson](https://github.com/robolson)

## 1.17.3

* Fixed issue with Rack response removing 'Content-Type' header

  Thanks to [Bo Jeanes](https://github.com/bjeanes) and [Matthew Conway](https://github.com/mattonrails)

## 1.17.2

* Support for chunked responses in Curb

  Thanks to [Zachary Belzer](https://github.com/zbelzer)

* Fixed handling of request body passed as a hash to `Typhoeus.post`

  Thanks to [Mason Chang](https://github.com/changmason) for reporting.

## 1.17.1

* Added missing license statements.

  Thanks to [Praveen Arimbrathodiyil](https://github.com/pravi)

## 1.17.0

* HTTP gem support!

  Thanks to [Aleksey V. Zapparov](https://github.com/ixti)

* Limited Excon gem requirement to version < 0.30 until the compatibility with version > 0.30.0 is fixed.

  Thanks to [Aleksey V. Zapparov](https://github.com/ixti)

* Fixed issue where empty query key caused a `TypeError`

  Thanks to [Jon Rowe](https://github.com/JonRowe)

* Handling Typhoeus `on_headers` and `on_body` params.

  Thanks to [Matt Burke](https://github.com/spraints)

## 1.16.1

* Fixed "NameError: uninitialized constant WebMock::Response::Pathname" issue.

  Thanks to [Alex Stupakow and Karen Wang](https://github.com/stupakov) for the fix.

## 1.16.0

* Allow a Pathname to be passed as a Response body

        stub_request(:get, /example.com/).to_return(
          body: Rails.root.join('test/fixtures/foo.txt')
        )

  Thanks to [Ben Pickles](https://github.com/benpickles)

* `hash_including` matcher can be initialized with empty keys to match any values.

        stub_request(:post, "www.example.com").with(:body => hash_including(:a, :b => {'c'}))
        RestClient.post('www.example.com', '{"a":"1","b":"c"}', :content_type => 'application/json')

  Thanks to [Stefano Uliari](https://github.com/steookk)

## 1.15.2

*  Fixed `hash_including` to accept a splat of solitary keys.

   Thanks to [Tamir Duberstein](https://github.com/tamird) and [https://github.com/strongriley](https://github.com/strongriley)

## 1.15.0

* Excon >= 0.27.5 compatibility.

  Thanks to [Brian D. Burns](https://github.com/burns)

## 1.14.0

* Handling non UTF-8 characters in query params.

  Thanks to [Florian Dütsch](https://github.com/der-flo) for reporting the issue.

* Added support for `request_block` param in Excon

  Thanks to [Dmitry Gutov](https://github.com/dgutov) for reporting the issue.

* Fixed compatibility with latest Curb

  Thanks to [Ian Lesperance](https://github.com/elliterate) and [Matthew Horan](https://github.com/mhoran)

* Triggering errbacks assynchronously in em-http-request adapter.

  Thanks to [Ian Lesperance](https://github.com/elliterate) and [Matthew Horan](https://github.com/mhoran)

* Handling query params with a hashes nested inside arrays.

  Thanks to [Ian Asaff](https://github.com/montague)

* Changed NetConnectNotAllowedError to inherit from Exception to allow it to bubble up into a test suite.

  Thanks to [Daniel van Hoesel](https://github.com/s0meone)

* HTTPClient adapter is thread safe.

  Thanks to [Tom Beauvais](https://github.com/tbeauvais)

## 1.13.0

* Net::HTTP::Persistent compatibility.
  WebMock doesn't disconnect previously started connections upon a request anymore.


## 1.12.3

* Fixed issue with handling Addressable::URI with query params passed to `Net::HTTP.get_response`

  Thanks to [Leif Bladt](https://github.com/leifbladt)

* Fixed HTTPClient adapter to not raise an error if a request with multipart body is executed.

## 1.12.2

* Fixed issue with handling request.path when Addressable::URI is passed to #request instead of URI with Ruby 2.0.

  Thanks to [Leif Bladt](https://github.com/leifbladt)

* Accept integers as query param values in request stubs

  i.e. `stub_request(:get, /.*/).with(:query => {"a" => 1})`

  Thanks to [Mitsutaka Mimura](https://github.com/takkanm)

## 1.12.1

* Fixed Minitest < 5.0 compatibility

  Thanks to [Alex Tomlins](https://github.com/alext) for reporting the issue.

## 1.12.0

* Not using Gem spec anymore to check loaded Curb version.

* `WebMock.disable_net_connect!` now accepts array of regexps as allow param:

  i.e. `WebMock.disable_net_connect!(:allow => [/google.com/, /yahoo.com/])`

  Thanks to [Bastien Vaucher](https://github.com/bastien)

* Fixed `on_header` Curb callback behaviour in Curb adapter

  Thanks to [Joel Chippindale](https://github.com/mocoso)

* Fixed aws-sdk compatibility with Ruby 2.0, by supporting `continue_timeout` accessor on Net::HTTP socket.

   Thanks to [Lin Jen-Shin](https://github.com/godfat)

* Fixed WebMock::Server to not give "log writing failed. can't be called from trap context" warning with Ruby 2.0

   Thanks to [Murahashi Sanemat Kenichi](https://github.com/sanemat)

* Added support for EM-HTTP-Request streaming data off disk feature.

   Thanks to [Lin Jen-Shin](https://github.com/godfat)

* Added compatibility with Minitest 5

   Thanks to [Tim Kurvers](https://github.com/timkurvers)

* Excon >= 0.22 compatibility.

* README has nice sytnax hightlighting and fixed code styling!

   Thanks to [Ilya Vassilevsky](https://github.com/vassilevsky)

* Compatibility with Rails 4 `rack.session.options`

   Thanks to [gotwalt](https://github.com/gotwalt)

## 1.11.0

* Excon >= 0.17 support.

  Thanks to [Nathan Sutton](https://github.com/nate) for reporting this issue and to [Wesley Beary](https://github.com/geemus) and [Myron Marston](https://github.com/myronmarston) for help.

## 1.10.2

* '+' in request path is treated as plus, but in query params always as a space.

## 1.10.1

* '+' in request body is still treated as a space. This fixes a bug introduced in previous version.

  Thanks to [Erik Michaels-Ober](https://github.com/sferik) for reporting this problem.

* Fixed issue: response body declared as Proc was not evaluated again on subsequent requests.

  Thanks to [Rick Fletcher](https://github.com/rfletcher) for reporting this issue.

## 1.10.0

* '+' in query params is not treated as space anymore and is encoded as %2B

  Thanks to [goblin](https://github.com/goblin) for reporting this issue.

* added `remove_request_stub` method to the api to allow removing unused stubs i.e.

        stub_get = stub_request(:get, "www.example.com")
        remove_request_stub(stub_get)

* `assert_requested` and `assert_not_requested` raise an error if a stub object is provided together with a block.

## 1.9.3

* Fixed issue with unavailable constant Mutex in Ruby < 1.9

  Thanks to [Lucas Dohmen](https://github.com/moonglum) for reporting this issue.

## 1.9.2

* Added support for Excon's :response_block parameter

  Thanks to [Myron Marston](https://github.com/myronmarston) for reporting this issue.

## 1.9.1

* Fix 'rack.errors' not being set for Rack apps

  Thanks to [Alex Grant](https://github.com/grantovich)

* Added support for minitest assertions count

  Thanks to [Mokevnin Kirill](https://github.com/mokevnin)

* Fixed issues with registering http requests in multi-threaded environments

  Thanks to [Tom Beauvais](https://github.com/tbeauvais)

* Bumped Crack version to >=0.3.2

  Thanks to [Jake Benilov](https://github.com/benilovj)

* Fixed issues in Typhoeus 0.6. Defaulted method to GET when no method specified.

  Thanks to [Hans Hasselberg](https://github.com/i0rek)

* Add license information to the gemspec

  Thanks to [Jordi Massaguer Pla](https://github.com/jordimassaguerpla) and [Murahashi Sanemat Kenichi](https://github.com/sanemat)

* Added support for :expects option in Excon adapter

  Thanks to [Evgeniy Dolzhenko](https://github.com/dolzenko)

* Fixed Faye compatibility by treating StringIO in Net::HTTP adapter properly

  Thanks to [Pavel Forkert](https://github.com/fxposter)

* Updated VCR link

  Thanks to [Rex Feng](https://github.com/xta)

## 1.9.0

* Added support for Typhoeus >= 0.5.0 and removed support for Typhoeus < 0.5.0.

  Thanks to [Hans Hasselberg](https://github.com/i0rek)

## 1.8.11

* Fix excon adapter to handle `:body => some_file_object`

  Thanks to [Myron Marston](https://github.com/myronmarston)

## 1.8.10

* em-http-request fix. After request callbacks are correctly invoked for 3xx responses,
  when :redirects option is set.

    Thanks to [Myron Marston](https://github.com/myronmarston) for reporting that issue.

* Fixed compatibility with Net::HTTP::DigestAuth

    Thanks to [Jonathan Hyman](https://github.com/jonhyman) for reporting that issue.

* Fixed problem in em-http-request 0.x appending the query to the client URI twice.

    Thanks to [Paweł Pierzchała](https://github.com/wrozka)

## 1.8.9

* Fixed problem with caching nil responses when the same HTTPClient instance is used.

    Thanks to [Myron Marston](https://github.com/myronmarston)

* Added support for Addressable >= 2.3.0. Addressable 2.3.0 removed support for multiple query value notations and broke backwards compatibility.

    https://github.com/sporkmonger/addressable/commit/f51e290b5f68a98293327a7da84eb9e2d5f21c62
    https://github.com/sporkmonger/addressable/issues/77


## 1.8.8

* Fixed Net::HTTP adapter so that it returns `nil` for an empty body response.

    Thanks to [Myron Marston](https://github.com/myronmarston)

* Gemspec defines compatibility with Addressable ~> 2.2.8, not >= 2.3.0

* Specs compatibility with Typhoeus 0.4.0

    Thanks to [Hans Hasselberg](https://github.com/i0rek)

* Handling content types that specify a charset

    Thanks to [Kevin Glowacz](https://github.com/kjg)

* Fixed em-http-request adapter to correctly fetch authorization header from a request

    Thanks to [Julien Boyer](https://github.com/chatgris)

* Fixing travis-ci image to report master's status

    Thanks to [Ryan Schlesinger](https://github.com/ryansch)

* Fixed problem with em-http-request callback triggering if there were other EM::Deferred callbacks registered

    Thanks to [Jon Leighton](https://github.com/jonleighton)

* Fixed problem with em-http-request appending the query to the URI a second time, and
the parameters are repeated.

    Thanks to [Jon Leighton](https://github.com/jonleighton)

## 1.8.7

* Compatibility with RSpec >= 2.10

    Thanks to [erwanlr](https://github.com/erwanlr) for reporting this issue.

* Add missing required rack environment variable SCRIPT_NAME

    Thanks to [Eric Oestrich](https://github.com/oestrich)

* Fixed warnings due to @query_params not being initialized

    Thanks to [Ben Bleything](https://github.com/bleything)

## 1.8.6

* Pass through SERVER_PORT when stubbing to rack

    Thanks to [Eric Oestrich](https://github.com/oestrich)

* Fixed problem with missing parenthesis in `WebMock#net_connect_allowed?` conditions.

    Thanks to [aindustries](https://github.com/aindustries)

## 1.8.5

* WebMock::RackResponse supports basic auth

    Thanks to [jugyo](https://github.com/jugyo)

## 1.8.4

* Warning message is printed when an unsupported version of a http library is loaded.

    Thanks to [Alexander Staubo](https://github.com/alexstaubo) for reporting the problem and to [Myron Marston](https://github.com/myronmarston) for a help with solution.

## 1.8.3

* Fixed compatibility with latest em-http-request

    Thanks to [Paul Cortens](https://github.com/thoughtless)

## 1.8.2

* Prevent Webmock `hash_including` from overriding RSpec version 1 `hash_including` method.

    Thanks to [Joe Karayusuf](https://github.com/karayusuf)

* Ensured WebMock handles RSpec 1 `hash_including` matcher for matching query params and body.

## 1.8.1

* Ensured WebMock doesn't interfere with `em-synchrony`, when `em-synchrony/em-http` is not included.

    Thanks to [Nick Recobra](https://github.com/oruen)

* Improved README

    Thanks to [Jordan Elver](https://github.com/jordelver)


## 1.8.0

* Matching request body against partial hash.

        stub_http_request(:post, "www.example.com").
                with(:body => hash_including({:data => {:a => '1', :b => 'five'}}))

        RestClient.post('www.example.com', "data[a]=1&data[b]=five&x=1",
        :content_type => 'application/x-www-form-urlencoded')    # ===> Success

        request(:post, "www.example.com").
        with(:body => hash_including({:data => {:a => '1', :b => 'five'}}),
        :headers => 'Content-Type' => 'application/json').should have_been_made         # ===> Success

    Thanks to [Marnen Laibow-Koser](https://github.com/marnen) for help with this solution

* Matching request query params against partial hash.

        stub_http_request(:get, "www.example.com").with(:query => hash_including({"a" => ["b", "c"]}))

        RestClient.get("http://www.example.com/?a[]=b&a[]=c&x=1") # ===> Success

        request(:get, "www.example.com").
          with(:query => hash_including({"a" => ["b", "c"]})).should have_been_made  # ===> Success

* Added support for Excon.

    Thanks to [Dimitrij Denissenko](https://github.com/dim)

* Added support for setting expectations on the request stub with `assert_requested`

        stub_get = stub_request(:get, "www.example.com")
        stub_post = stub_request(:post, "www.example.com")

        Net::HTTP.get('www.example.com', '/')

        assert_requested(stub_get)
        assert_not_requested(stub_post)

    Thanks to [Nicolas Fouché](https://github.com/nfo)

* `WebMock.disable_net_connect!` accepts `RegExp` as `:allow` parameter

    Thanks to [Frank Schumacher](https://github.com/thenoseman)

* Ensure multiple values for the same header can be recorded and played back

    Thanks to [Myron Marston](https://github.com/myronmarston)

* Updated dependency on Addressable to version >= 2.2.7 to handle nested hash query values. I.e. `?one[two][three][]=four&one[two][three][]=five`

* Fixed compatibility with Curb >= 0.7.16 This breaks compatibility with Curb < 0.7.16

* Fix #to_rack to handle non-array response bodies.

    Thanks to [Tammer Saleh](https://github.com/tsaleh)

* Added `read_timeout` accessor to StubSocket which fixes compatibility with aws-sdk

    Thanks to [Lin Jen-Shin](https://github.com/godfat)

* Fix warning "instance variable @query_params not initialized"

    Thanks to [Joe Van Dyk](https://github.com/joevandyk)

* Using bytesize of message instead of its length for content-length header in em-http-request adapter.
  This fixes a problem with messages getting truncated in Ruby >= 1.9

    Thanks to [Mark Abramov](https://github.com/markiz)

* Fixed problem with body params being matched even if params were different.

    Thanks to [Evgeniy Dolzhenko](https://github.com/dolzenko) for reporting this issue.

## 1.7.10

* Yanked 1.7.9 and rebuilt gem on 1.8.7 to deal with syck/psych incompatibilties in gemspec.

## 1.7.9

* Fixed support for native Typhoeus timeouts.

    Thanks to [Albert Llop](https://github.com/mrsimo)

* Fixed problem with WebMock and RSpec compatibility on TeamCity servers. See [this article](http://www.coding4streetcred.com/blog/post/Issue-RubyMine-31-Webmock-162-and-%E2%80%9CSpecconfigure%E2%80%9D-curse.aspx) for more details.

    Thanks to [Christopher Pickslay](https://github.com/chrispix) from [Two Bit Labs](https://github.com/twobitlabs)


## 1.7.8

* Fix each adapter so that it calls a `stub.with` block only once per
  request. Previously, the block would be called two or three times per
  request [Myron Marston](https://github.com/myronmarston).

## 1.7.7 - RuPy 2011 release

* Passing response object to a block passed to `HTTPClient#do_get_block`. This fixes `HTTPClient.get_content` failures. [issue 130](https://github.com/bblimke/webmock/pull/130)

    Thanks to [Chris McGrath](https://github.com/chrismcg)

* Cleaned up ruby warnings when running WebMock code with `-w`.

    Thanks to [Stephen Celis](https://github.com/stephencelis)

* Curb adapter now correctly calls on_failure for 4xx response codes.

    Thanks to [Eugene Pimenov](https://github.com/libc)

## 1.7.6

* Support for the HTTPClient's request_filter feature

   Thanks to [Roman Shterenzon](https://github.com/romanbsd)

## 1.7.5

* Added support for Patron 0.4.15. This change is not backward compatible so please upgrade Patron to version >= 0.4.15 if you want to use it with WebMock.

   Thanks to [Andreas Garnæs](https://github.com/andreas)

## 1.7.4

* Added support for matching EM-HTTP-Request requests with body declared as a Hash

   Thanks to [David Yeu](https://github.com/daveyeu)

## 1.7.3

* Added `Get`, `Post`, `Delete`, `Put`, `Head`, `Option` constants to replaced `Net::HTTP` to make it possible to marshal objects with these constants assigned to properties. This fixed problem with `tvdb_party` gem which serializes HTTParty responses.

  Thanks to [Klaus Hartl](https://github.com/carhartl) for reporting this issue.

## 1.7.2

* Redefined `const_get` and `constants` methods on the replaced `Net::HTTP` to return same values as original `Net::HTTP`

## 1.7.1

* Redefined `const_defined?` on the replaced `Net::HTTP` so that it returns true if constant is defined on the original `Net::HTTP`. This fixes problems with `"Net::HTTP::Get".constantize`.

   Thanks to [Cássio Marques](https://github.com/cassiomarques) for reporting the issue and to [Myron Marston](https://github.com/myronmarston) for help with the solution.

## 1.7.0

* Fixed Net::HTTP adapter to not break normal Net::HTTP behaviour when network connections are allowed. This fixes **selenium-webdriver compatibility**!!!

* Added support for EM-HTTP-Request 1.0.x and EM-Synchrony. Thanks to [Steve Hull](https://github.com/sdhull)

* Added support for setting expectations to on a stub itself i.e.

        stub = stub_request(:get, "www.example.com")
        # ... make requests ...
        stub.should have_been_requested

  Thanks to [Aidan Feldman](https://github.com/afeld)

* Minitest support! Thanks to [Peter Higgins](https://github.com/phiggins)

* Added support for Typhoeus::Hydra

* Added support for `Curb::Easy#http_post` and `Curb::Easy#http_post` with multiple arguments. Thanks to [Salvador Fuentes Jr](https://github.com/fuentesjr) and [Alex Rothenberg](https://github.com/alexrothenberg)

* Rack support. Requests can be stubbed to respond with a Rack app i.e.

        class MyRackApp
          def self.call(env)
            [200, {}, ["Hello"]]
          end
        end

        stub_request(:get, "www.example.com").to_rack(MyRackApp)

        RestClient.get("www.example.com") # ===> "Hello"


    Thanks to [Jay Adkisson](https://github.com/jayferd)

* Added support for selective disabling and enabling of http lib adapters

        WebMock.disable!                         #disable WebMock (all adapters)
        WebMock.disable!(:except => [:net_http]) #disable WebMock for all libs except Net::HTTP
        WebMock.enable!                          #enable WebMock (all adapters)
        WebMock.enable!(:except => [:patron])    #enable WebMock for all libs except Patron

* The error message on an unstubbed request shows a code snippet with body as a hash when it was in url encoded form.

        > RestClient.post('www.example.com', "data[a]=1&data[b]=2", :content_type => 'application/x-www-form-urlencoded')

        WebMock::NetConnectNotAllowedError: Real HTTP connections are disabled....

        You can stub this request with the following snippet:

        stub_request(:post, "http://www.example.com/").
          with(:body => {"data"=>{"a"=>"1", "b"=>"2"}},
               :headers => { 'Content-Type'=>'application/x-www-form-urlencoded' }).
          to_return(:status => 200, :body => "", :headers => {})

    Thanks to [Alex Rothenberg](https://github.com/alexrothenberg)

* The error message on an unstubbed request shows currently registered request stubs.

        > stub_request(:get, "www.example.net")
        > stub_request(:get, "www.example.org")
        > RestClient.get("www.example.com")
        WebMock::NetConnectNotAllowedError: Real HTTP connections are disabled....

        You can stub this request with the following snippet:

        stub_request(:get, "http://www.example.com/").
          to_return(:status => 200, :body => "", :headers => {})

        registered request stubs:

        stub_request(:get, "http://www.example.net/")
        stub_request(:get, "http://www.example.org/")

    Thanks to [Lin Jen-Shin](https://github.com/godfat) for suggesting this feature.

* Fixed problem with matching requests with json body, when json strings have date format. Thanks to [Joakim Ekberg](https://github.com/kalasjocke) for reporting this issue.

* WebMock now attempts to require each http library before monkey patching it. This is to avoid problem when http library is required after WebMock is required. Thanks to [Myron Marston](https://github.com/myronmarston) for suggesting this change.

* External requests can be disabled while allowing selected ports on selected hosts

        WebMock.disable_net_connect!(:allow => "www.example.com:8080")
        RestClient.get("www.example.com:80") # ===> Failure
        RestClient.get("www.example.com:8080")  # ===> Allowed.

    Thanks to [Zach Dennis](https://github.com/zdennis)

* Fixed syntax error in README examples, showing the ways of setting request expectations. Thanks to [Nikita Fedyashev](https://github.com/nfedyashev)


**Many thanks to WebMock co-maintainer [James Conroy-Finn](https://github.com/jcf) who did a great job maintaining WebMock on his own for the last couple of months.**

## 1.6.4

This is a quick slip release to regenerate the gemspec. Apparently
jeweler inserts dependencies twice if you use the `gemspec` method in
your Gemfile and declare gem dependencies in your gemspec.

https://github.com/technicalpickles/jeweler/issues/154

josevalim:

> This just bit me. I just released a gem with the wrong dependencies
> because I have updated jeweler. This should have been opt-in,
> otherwise a bunch of people using jeweler are going to release gems
> with the wrong dependencies because you are automatically importing
> from the Gemfile.

## 1.6.3

* Update the dependency on addressable to get around an issue in v2.2.5.
  Thanks to [Peter Higgins](https://github.com/phiggins).

* Add support for matching parameter values using a regular expression
  as well as a string. Thanks to [Oleg M Prozorov](https://github.com/oleg).

* Fix integration with httpclient as the internal API has changed.
  Thanks to [Frank Prößdorf](https://github.com/endor).

* Ensure Curl::Easy#content_type is always set. Thanks to [Peter
  Higgins](https://github.com/phiggins).

* Fix bug with em-http-request adapter stubbing responses that have a
  chunked transfer encoding. Thanks to [Myron
  Marston](https://github.com/myronmarston).

* Fix a load of spec failures with Patron, httpclient, and specs that
  depended on the behaviour of example.com. Thanks to [Alex
  Grigorovich](https://github.com/grig).

## 1.6.2

* Em-http-request adapter sets `last_effective_url` property. Thanks to [Sam Stokes](https://github.com/samstokes).

* Curb adapter supports `Curb::Easy#http_post` and `Curb::Easy#http_put` without arguments (by setting `post_body` or `put_data` beforehand). Thanks to [Eugene Bolshakov](https://github.com/eugenebolshakov)

## 1.6.1

* Fixed issue with `webmock/rspec` which didn't load correctly if `rspec/core` was already required but `rspec/expectations` not.

## 1.6.0

* Simplified integration with Test::Unit, RSpec and Cucumber. Now only a single file has to be required i.e.

                require 'webmock/test_unit'
                require 'webmock/rspec'
                require 'webmock/cucumber'

* The error message on unstubbed request now contains code snippet which can be used to stub this request. Thanks to Martyn Loughran for suggesting this feature.

* The expectation failure message now contains a list of made requests. Thanks to Martyn Loughran for suggesting this feature.

* Added `WebMock.print_executed_requests` method which can be useful to find out what requests were made until a given point.

* em-http-request adapter is now activated by replacing EventMachine::HttpRequest constant, instead of monkeypatching the original class.

 This technique is borrowed from em-http-request native mocking module. It allows switching WebMock adapter on an off, and using it interchangeably with em-http-request native mocking i.e:

                EventMachine::WebMockHttpRequest.activate!
                EventMachine::WebMockHttpRequest.deactivate!

        Thanks to Martyn Loughran for suggesting this feature.

* `WebMock.reset_webmock` is deprecated in favour of new `WebMock.reset!`

* Fixed integration with Cucumber. Previously documented example didn't work with new versions of Cucumber.

* Fixed stubbing requests with body declared as a hash. Thanks to Erik Michaels-Ober for reporting the issue.

* Fixed issue with em-http-request adapter which didn't work when :query option value was passed as a string, not a hash. Thanks to Chee Yeo for reporting the issue.

* Fixed problem with assert_requested which didn't work if used outside rspec or test/unit

* Removed dependency on json gem

## 1.5.0

* Support for dynamically evaluated raw responses recorded with `curl -is` <br/>
  i.e.

                `curl -is www.example.com > /tmp/www.example.com.txt`
                stub_request(:get, "www.example.com").to_return(lambda { |request| File.new("/tmp/#{request.uri.host.to_s}.txt" }))

* `:net_http_connect_on_start` option can be passed to `WebMock.allow_net_connect!` and `WebMock.disable_net_connect!` methods, i.e.

                WebMock.allow_net_connect!(:net_http_connect_on_start => true)

  This forces WebMock Net::HTTP adapter to always connect on `Net::HTTP.start`. Check 'Connecting on Net::HTTP.start' in README for more information.

  Thanks to Alastair Brunton for reporting the issue and for fix suggestions.

* Fixed an issue where Patron spec tried to remove system temporary directory.
  Thanks to Hans de Graaff

* WebMock specs now use RSpec 2

* `rake spec NO_CONNECTION=true` can now be used to only run WebMock specs which do not make real network connections

## 1.4.0

* Curb support!!! Thanks to the awesome work of Pete Higgins!

* `include WebMock` is now deprecated to avoid method and constant name conflicts. Please `include WebMock::API` instead.

* `WebMock::API#request` is renamed to `WebMock::API#a_request` to prevent method name conflicts with i.e. Rails controller specs.
  WebMock.request is still available.

* Deprecated `WebMock#request`, `WebMock#allow_net_connect!`, `WebMock#net_connect_allowed?`, `WebMock#registered_request?`, `WebMock#reset_callbacks`, `WebMock#after_request` instance methods. These methods are still available, but only as WebMock class methods.

* Removed `WebMock.response_for_request` and `WebMock.assertion_failure` which were only used internally and were not documented.

* :allow_localhost => true' now permits 0.0.0.0 in addition to 127.0.0.1 and 'localhost'. Thanks to Myron Marston and Mike Gehard for suggesting this.

* Fixed issue with both RSpec 1.x and 2.x being available.

  WebMock now tries to use already loaded version of RSpec (1.x or 2.x). Previously it was loading RSpec 2.0 if available, even if RSpec 1.3 was already loaded.

  Thanks to Hans de Graaff for reporting this.

* Changed runtime dependency on Addressable version 2.2.2 which fixes handling of percent-escaped '+'

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
        :headers => 'Content-Type' => 'application/json').should have_been_made         # ===> Success

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
