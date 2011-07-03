Feature: Stubbing requests using only a URI

  WebMock can stub requests using only a URI

  Background:
    Given a file named "setup.rb" with:
      """
      require 'net/http'
      require 'web_mock'
      """

  Scenario: Sending a get to a host that isn't stubbed produces an error
    Given a file named "stub_request.rb" with:
      """
      require './setup'

      WebMock.stub_request(:any, 'www.example.com')

      Net::HTTP.get("www.example.com", "/")
      Net::HTTP.get("www.google.com", "/")
      """
    When I run `ruby stub_request.rb`
    Then the output should contain:
    """
    Real HTTP connections are disabled. Unregistered request: GET http://www.google.com/ with headers {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}
    """

  Scenario: Sending a post to a host that is stubbed
    Given a file named "stub_request.rb" with:
      """
      require './setup'

      WebMock.stub_request(:post, 'www.example.com').
        with(:body => 'abc')

      uri = URI.parse("http://www.example.com/")
      req = Net::HTTP::Post.new(uri.path)
      req['Content-Length'] = 3
      Net::HTTP.start(uri.host, uri.port) {|http|
        http.request(req, "abc")
      }
      """
    When I run `ruby stub_request.rb`
    Then it should pass with exactly:
    """
    """

  @wip
  Scenario: Sending a post to a host with matching headers
    Given a file named "stub_request.rb" with:
      """
      require './setup'

      WebMock.stub_request(:post, 'www.example.com').
        with(:body => 'abc',
             :headers => {'Accept'=>'*/*', 'Content-Length'=>'3', 'User-Agent'=>'Ruby'})

      uri = URI.parse("http://www.example.com/")
      req = Net::HTTP::Post.new(uri.path)
      req['Content-Length'] = 3
      Net::HTTP.start(uri.host, uri.port) {|http|
        http.request(req, "abc")
      }
      """
    When I run `ruby stub_request.rb`
    Then it should pass with exactly:
    """
    """

