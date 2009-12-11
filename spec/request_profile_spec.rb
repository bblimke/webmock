require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RequestProfile do

  describe "initialization" do

    it "should have assigned normalized uri" do
      WebMock::Util::URI.should_receive(:normalize_uri).and_return("www.example.kom")
      profile = RequestProfile.new(:get, "www.example.com")
      profile.uri.should == "www.example.kom"
    end

    it "should have assigned uri without normalization if uri is URI" do
      WebMock::Util::URI.should_not_receive(:normalize_uri)
      uri = Addressable::URI.parse("www.example.com")
      profile = RequestProfile.new(:get, uri)
      profile.uri.should == uri
    end

    it "should have assigned normalized headers" do
      WebMock::Util::Headers.should_receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
      RequestProfile.new(:get, "www.example.com", :headers => {'A' => 'a'}).headers.should == {'B' => 'b'}
    end

    it "should have assigned body" do
      RequestProfile.new(:get, "www.example.com", :body => "abc").
        body.should == RequestProfile::Body.new("abc")
    end

  end

  it "should report string describing itself" do
    RequestProfile.new(:get, "www.example.com",
      :body => "abc", :headers => {'A' => 'a', 'B' => 'b'}).to_s.should ==
    "GET http://www.example.com/ with body 'abc' with headers {'A'=>'a', 'B'=>'b'}"
  end


  describe "with" do
    before(:each) do
      @request_profile = RequestProfile.new(:get, "www.example.com")
    end

    it "should assign body to request profile" do
      @request_profile.with(:body => "abc")
      @request_profile.body.should == RequestProfile::Body.new("abc")
    end

    it "should have the same body" do
      @request_profile.with(:body => "abc")
      @request_profile.body.should == RequestProfile::Body.new("abc")
    end

    it "should assign normalized headers to request profile" do
      WebMock::Util::Headers.should_receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
      @request_profile.with(:headers => {'A' => 'a'})
      @request_profile.headers.should == {'B' => 'b'}
    end

  end


end
