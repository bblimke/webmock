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
      uri = Addressable::URI.parse("www.google.com")
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

  it "should report string describing itself" do
    RequestProfile.new(:get, "www.google.com", "abc", {'A' => 'a', 'B' => 'b'}).to_s.should ==
    "GET http://www.google.com:80/ with body 'abc' with headers {'A'=>'a', 'B'=>'b'}"
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


end
