require File.join(File.dirname(__FILE__), "test_helper")

require 'ostruct' 
 
class TestWebMock < Test::Unit::TestCase
    
  def http_request(method, url, options = {})
    url = URI.parse(url)
    response = nil
    clazz = Net::HTTP.const_get("#{method.to_s.capitalize}")
    req = clazz.new(url.path, options[:headers])
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true if url.scheme == "https"
    response = http.start {|http|
      http.request(req, options[:body])
    }
    OpenStruct.new({
      :body => response.body,
      :headers => response,
      :status => response.code })
  end  

  
  def setup
    super
    stub_http_request(:any, "http://www.google.com")
    stub_http_request(:any, "https://www.google.com")
  end
    
  def test_verification_that_expected_request_occured
    http_request(:get, "http://www.google.com/")
    assert_requested(:get, "http://www.google.com", :times => 1)
    assert_requested(:get, "http://www.google.com")
  end
  
  def test_verification_that_expected_request_didnt_occur
    assert_fail("The request GET http://www.google.com/ was expected to execute 1 time but it executed 0 times") do
      assert_requested(:get, "http://www.google.com")
    end
  end  

  def test_verification_that_expected_request_occured_with_body_and_headers
    http_request(:get, "http://www.google.com/",
      :body => "abc", :headers => {'A' => 'a'})
    assert_requested(:get, "http://www.google.com",
      :body => "abc", :headers => {'A' => 'a'})
  end

  def test_verification_that_non_expected_request_didnt_occur
    assert_fail("The request GET http://www.google.com/ was expected to execute 0 times but it executed 1 time") do
      http_request(:get, "http://www.google.com/")
      assert_not_requested(:get, "http://www.google.com")
    end
  end

end
