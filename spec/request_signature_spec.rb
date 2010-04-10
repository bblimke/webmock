require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RequestSignature do
  
  describe "initialization" do

    it "should have assigned normalized uri" do
      WebMock::Util::URI.should_receive(:normalize_uri).and_return("www.example.kom")
      signature = RequestSignature.new(:get, "www.example.com")
      signature.uri.should == "www.example.kom"
    end

    it "should have assigned uri without normalization if uri is URI" do
      WebMock::Util::URI.should_not_receive(:normalize_uri)
      uri = Addressable::URI.parse("www.example.com")
      signature = RequestSignature.new(:get, uri)
      signature.uri.should == uri
    end

    it "should have assigned normalized headers" do
      WebMock::Util::Headers.should_receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
      RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}).headers.should == {'B' => 'b'}
    end

    it "should have assigned body" do
      RequestSignature.new(:get, "www.example.com", :body => "abc").body.should == "abc"
    end

  end

  it "should report string describing itself" do
    RequestSignature.new(:get, "www.example.com",
      :body => "abc", :headers => {'A' => 'a', 'B' => 'b'}).to_s.should ==
    "GET http://www.example.com/ with body 'abc' with headers {'A'=>'a', 'B'=>'b'}"
  end
  
end