require File.expand_path(File.dirname(__FILE__) + '/http_request')

module SharedTest
  include HttpRequestTestHelper

  def setup
    super
    @stub_http = stub_http_request(:any, "http://www.example.com")
    @stub_https = stub_http_request(:any, "https://www.example.com")
  end

  def test_assert_requested_with_stub_and_block_raises_error
    assert_raises ArgumentError do
      assert_requested(@stub_http) {}
    end
  end

  def test_assert_not_requested_with_stub_and_block_raises_error
    assert_raises ArgumentError do
      assert_not_requested(@stub_http) {}
    end
  end

  def test_error_on_non_stubbed_request
    assert_raise_with_message(WebMock::NetConnectNotAllowedError, %r{Real HTTP connections are disabled. Unregistered request: GET http://www.example.net/ with headers}) do
      http_request(:get, "http://www.example.net/")
    end
  end

  def test_verification_that_expected_request_occured
    http_request(:get, "http://www.example.com/")
    assert_requested(:get, "http://www.example.com", times: 1)
    assert_requested(:get, "http://www.example.com")
  end

  def test_verification_that_expected_stub_occured
    http_request(:get, "http://www.example.com/")
    assert_requested(@stub_http, times: 1)
    assert_requested(@stub_http)
  end

  def test_verification_that_expected_request_didnt_occur
    expected_message = "The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times"
    expected_message += "\n\nThe following requests were made:\n\nNo requests were made.\n============================================================"
    assert_fail(expected_message) do
      assert_requested(:get, "http://www.example.com")
    end
  end

  def test_verification_that_expected_stub_didnt_occur
    expected_message = "The request ANY http://www.example.com/ was expected to execute 1 time but it executed 0 times"
    expected_message += "\n\nThe following requests were made:\n\nNo requests were made.\n============================================================"
    assert_fail(expected_message) do
      assert_requested(@stub_http)
    end
  end

  def test_verification_that_expected_request_occured_with_body_and_headers
    http_request(:get, "http://www.example.com/",
      body: "abc", headers: {'A' => 'a'})
    assert_requested(:get, "http://www.example.com",
      body: "abc", headers: {'A' => 'a'})
  end

  def test_verification_that_expected_request_occured_with_query_params
    stub_request(:any, "http://www.example.com").with(query: hash_including({"a" => ["b", "c"]}))
    http_request(:get, "http://www.example.com/?a[]=b&a[]=c&x=1")
    assert_requested(:get, "http://www.example.com",
      query: hash_including({"a" => ["b", "c"]}))
  end

  def test_verification_that_expected_request_not_occured_with_query_params
    stub_request(:any, 'http://www.example.com').with(query: hash_including(a: ['b', 'c']))
    stub_request(:any, 'http://www.example.com').with(query: hash_excluding(a: ['b', 'c']))
    http_request(:get, 'http://www.example.com/?a[]=b&a[]=c&x=1')
    assert_not_requested(:get, 'http://www.example.com', query: hash_excluding('a' => ['b', 'c']))
  end

  def test_verification_that_expected_request_occured_with_excluding_query_params
    stub_request(:any, 'http://www.example.com').with(query: hash_excluding('a' => ['b', 'c']))
    http_request(:get, 'http://www.example.com/?a[]=x&a[]=y&x=1')
    assert_requested(:get, 'http://www.example.com', query: hash_excluding('a' => ['b', 'c']))
  end

  def test_verification_that_non_expected_request_didnt_occur
    expected_message = %r(The request GET http://www.example.com/ was not expected to execute but it executed 1 time\n\nThe following requests were made:\n\nGET http://www.example.com/ with headers .+ was made 1 time\n\n============================================================)
    assert_fail(expected_message) do
      http_request(:get, "http://www.example.com/")
      assert_not_requested(:get, "http://www.example.com")
    end
  end

  def test_refute_requested_alias
    expected_message = %r(The request GET http://www.example.com/ was not expected to execute but it executed 1 time\n\nThe following requests were made:\n\nGET http://www.example.com/ with headers .+ was made 1 time\n\n============================================================)
    assert_fail(expected_message) do
      http_request(:get, "http://www.example.com/")
      refute_requested(:get, "http://www.example.com")
    end
  end

  def test_verification_that_non_expected_stub_didnt_occur
    expected_message = %r(The request ANY http://www.example.com/ was not expected to execute but it executed 1 time\n\nThe following requests were made:\n\nGET http://www.example.com/ with headers .+ was made 1 time\n\n============================================================)
    assert_fail(expected_message) do
      http_request(:get, "http://www.example.com/")
      assert_not_requested(@stub_http)
    end
  end
end
