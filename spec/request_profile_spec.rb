require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

include WebMock

describe RequestProfile do

  describe "initialization" do

    it "should have assigned normalized uri" do
      URL.should_receive(:normalize_uri).and_return("www.google.kom")
      profile = RequestProfile.new(:get, "www.google.com")
      profile.uri.should == "www.google.kom"
    end

    it "should have assigned uri without normalization if uri is URI" do
      URL.should_not_receive(:normalize_uri)
      uri = URI.parse("www.google.com")
      profile = RequestProfile.new(:get, uri)
      profile.uri.should == uri
    end

    it "should have assigned normalized headers" do
      Utility.should_receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
      RequestProfile.new(:get, "www.google.com", nil, 'A' => 'a').headers.should == {'B' => 'b'}
    end

    it "should have assigned body" do
      RequestProfile.new(:get, "www.google.com", "abc").body.should == "abc"
    end

  end

  it "should report string" do
    RequestProfile.new(:get, "www.google.com", "abc", {'A' => 'a', 'B' => 'b'}).to_s.should ==
    "GET http://www.google.com/ with body 'abc' with headers {'A'=>'a', 'B'=>'b'}"
  end


  describe "with" do
    before(:each) do
      @request_profile = RequestProfile.new(:get, "www.google.com")
    end

    it "should assign body to request profile" do
      @request_profile.with(:body => "abc")
      @request_profile.body.should == "abc"
    end

    it "should assign normalized headers to request profile" do
      Utility.should_receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
      @request_profile.with(:headers => {'A' => 'a'})
      @request_profile.headers.should == {'B' => 'b'}
    end

  end

  describe "when matching" do

    it "should match if url matches and method matches" do
      RequestProfile.new(:get, "www.google.com").
        should match(RequestProfile.new(:get, "www.google.com"))
    end

    it "should match if url matches and method is any" do
      RequestProfile.new(:get, "www.google.com").
        should match(RequestProfile.new(:any, "www.google.com"))
    end

    it "should not match if other request profile has different method" do
      RequestProfile.new(:get, "www.google.com").
        should_not match(RequestProfile.new(:post, "www.google.com"))
    end

    it "should match if uri matches other uri" do
      RequestProfile.new(:get, "www.google.com").
        should match(RequestProfile.new(:get, "www.google.com"))
    end

    it "should match if uri matches other regex uri" do
      RequestProfile.new(:get, "www.google.com").
        should match(RequestProfile.new(:get, /.*google.*/))
    end

    it "should match for uris with same parameters" do
      RequestProfile.new(:get, "www.google.com?a=1&b=2").
        should match(RequestProfile.new(:get, "www.google.com?a=1&b=2"))
    end

    it "should not match for uris with different parameters" do
      RequestProfile.new(:get, "www.google.com?a=2&b=1").
        should_not match(RequestProfile.new(:get, "www.google.com?a=1&b=2"))
    end

    it "should match for parameters in different order" do
      RequestProfile.new(:get, "www.google.com?a=1&b=2").
        should match(RequestProfile.new(:get, "www.google.com?b=2&a=1"))
    end

    it "should match for same bodies" do
      RequestProfile.new(:get, "www.google.com", "abc").
        should match(RequestProfile.new(:get, "www.google.com", "abc"))
    end

    it "should not match for different bodies" do
      RequestProfile.new(:get, "www.google.com", "abc").
        should_not match(RequestProfile.new(:get, "www.google.com", "def"))
    end

    it "should match is other has nil body" do
      RequestProfile.new(:get, "www.google.com", "abc").
        should match(RequestProfile.new(:get, "www.google.com", nil))
    end

    it "should not match if other has empty body" do
      RequestProfile.new(:get, "www.google.com", "abc").
        should_not match(RequestProfile.new(:get, "www.google.com", ""))
    end

    it "should match for same headers" do
      RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg').
        should match(RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg'))
    end

    it "should not match for different values of the same header" do
      RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg').
        should_not match(RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/png'))
    end

    it "should match if request has more headers than other" do
      RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg', 'Content-Length' => '8888').
        should match(RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg'))
    end

    it "should not match if request has less headers that the other and all match" do
      RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg').
        should_not match(RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg', 'Content-Length' => '8888'))
    end

    it "should match even is header keys or values are in different format" do
      RequestProfile.new(:get, "www.google.com", nil, :ContentLength => 8888, 'content_type' => 'image/png').
        should match(RequestProfile.new(:get, "www.google.com", nil, 'ContentLength' => '8888', 'Content-type' => 'image/png'))
    end

    it "should match is other has nil headers" do
      RequestProfile.new(:get, "www.google.com", nil, 'A' => 'a').
        should match(RequestProfile.new(:get, "www.google.com", nil, nil))
    end

    it "should not match if other has empty headers" do
      RequestProfile.new(:get, "www.google.com", nil, 'A' => 'a').
        should_not match(RequestProfile.new(:get, "www.google.com", nil, {}))
    end

    it "should not match if profile has no headers but other has headers" do
      RequestProfile.new(:get, "www.google.com", nil, nil).
        should_not match(RequestProfile.new(:get, "www.google.com", nil, {'A'=>'a'}))
    end

    it "should not match if profile has empty headers but other has headers" do
      RequestProfile.new(:get, "www.google.com", nil, {}).
        should_not match(RequestProfile.new(:get, "www.google.com", nil, {'A'=>'a'}))
    end

  end

end
