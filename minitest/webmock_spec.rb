require File.expand_path(File.dirname(__FILE__) + '/test_helper')

  describe "Webmock" do
    include HttpRequestTestHelper

    before do
      @stub_http = stub_http_request(:any, "http://www.example.com")
      @stub_https = stub_http_request(:any, "https://www.example.com")
    end

    it "should update assertions count" do
      assert_equal 0, assertions
      http_request(:get, "http://www.example.com/")

      assert_requested(@stub_http)
      assert_equal 2, assertions

      assert_not_requested(:post, "http://www.example.com")
      assert_equal 4, assertions
    end

    it "should raise error on non stubbed request" do
      lambda { http_request(:get, "http://www.example.net/") }.must_raise(WebMock::NetConnectNotAllowedError)
    end

    it "should verify that expected request occured" do
      http_request(:get, "http://www.example.com/")
      assert_requested(:get, "http://www.example.com", :times => 1)
      assert_requested(:get, "http://www.example.com")
    end

    it "should verify that expected http stub occured" do
      http_request(:get, "http://www.example.com/")
      assert_requested(@stub_http, :times => 1)
      assert_requested(@stub_http)
    end

    it "should verify that expected https stub occured" do
      http_request(:get, "https://www.example.com/")
      http_request(:get, "https://www.example.com/")
      assert_requested(@stub_https, :times => 2)
    end

    it  "should verify that expect request didn't occur" do
     expected_message = "The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times"
     expected_message << "\n\nThe following requests were made:\n\nNo requests were made.\n============================================================"
     assert_fail(expected_message) do
       assert_requested(:get, "http://www.example.com")
     end
    end

    it  "should verify that expect stub didn't occur" do
     expected_message = "The request ANY http://www.example.com/ was expected to execute 1 time but it executed 0 times"
     expected_message << "\n\nThe following requests were made:\n\nNo requests were made.\n============================================================"
     assert_fail(expected_message) do
       assert_requested(@stub_http)
     end
    end
  end

