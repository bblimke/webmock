require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RequestSignature do

  describe "when matching" do

    it "should match if uri matches and method matches" do
      RequestSignature.new(:get, "www.example.com").
        should match(RequestProfile.new(:get, "www.example.com"))
    end

    it "should match if uri matches and method is any" do
      RequestSignature.new(:get, "www.example.com").
        should match(RequestProfile.new(:any, "www.example.com"))
    end

    it "should not match if other request profile has different method" do
      RequestSignature.new(:get, "www.example.com").
        should_not match(RequestProfile.new(:post, "www.example.com"))
    end

    it "should match if uri matches other uri" do
      RequestSignature.new(:get, "www.example.com").
        should match(RequestProfile.new(:get, "www.example.com"))
    end
    
    it "should match if uri matches other escaped using uri" do
      RequestSignature.new(:get, "www.example.com/my path").
        should match(RequestProfile.new(:get, "www.example.com/my%20path"))
    end
    
    it "should match if unescaped uri matches other uri" do
      RequestSignature.new(:get, "www.example.com/my%20path").
        should match(RequestProfile.new(:get, "www.example.com/my path"))
    end
    
    it "should match if unescaped uri matches other regexp uri" do
      RequestSignature.new(:get, "www.example.com/my%20path").
        should match(RequestProfile.new(:get, /.*my path.*/))
    end

    it "should match if uri matches other regex uri" do
      RequestSignature.new(:get, "www.example.com").
        should match(RequestProfile.new(:get, /.*example.*/))
    end

    it "should match for uris with same parameters" do
      RequestSignature.new(:get, "www.example.com?a=1&b=2").
        should match(RequestProfile.new(:get, "www.example.com?a=1&b=2"))
    end

    it "should not match for uris with different parameters" do
      RequestSignature.new(:get, "www.example.com?a=2&b=1").
        should_not match(RequestProfile.new(:get, "www.example.com?a=1&b=2"))
    end

    it "should match for parameters in different order" do
      RequestSignature.new(:get, "www.example.com?a=1&b=2").
        should match(RequestProfile.new(:get, "www.example.com?b=2&a=1"))
    end
    
    describe "when parameters are escaped" do
    
      it "should match if uri with non escaped parameters is the same as other uri with escaped parameters" do
        RequestSignature.new(:get, "www.example.com/?a=a b").
          should match(RequestProfile.new(:get, "www.example.com/?a=a%20b"))
      end
    
      it "should match if uri with escaped parameters is the same as other uri with non escaped parameters" do
        RequestSignature.new(:get, "www.example.com/?a=a%20b").
          should match(RequestProfile.new(:get, "www.example.com/?a=a b"))
      end
    
      it "should match if other regexp is for non escaped parameters but uri has escaped parameters" do
        RequestSignature.new(:get, "www.example.com/?a=a%20b").
          should match(RequestProfile.new(:get, /.*a=a b.*/))
      end
    
      it "should match if other regexp is for escaped parameters but uri has non escaped parameters"  do
        RequestSignature.new(:get, "www.example.com/?a=a b").
          should match(RequestProfile.new(:get, /.*a=a%20b.*/))
      end
    
    end
    
    

    it "should match for same bodies" do
      RequestSignature.new(:get, "www.example.com", :body => "abc").
        should match(RequestProfile.new(:get, "www.example.com", :body => "abc"))
    end
    
    it "should match for body matching regexp" do
      RequestSignature.new(:get, "www.example.com", :body => "abc").
        should match(RequestProfile.new(:get, "www.example.com", :body => /^abc$/))
    end

    it "should not match for different bodies" do
      RequestSignature.new(:get, "www.example.com", :body => "abc").
        should_not match(RequestProfile.new(:get, "www.example.com", :body => "def"))
    end
    
    it "should not match for body not matching regexp" do
      RequestSignature.new(:get, "www.example.com", :body => "xabc").
        should_not match(RequestProfile.new(:get, "www.example.com", :body => /^abc$/))
    end

    it "should match if other has not specified body" do
      RequestSignature.new(:get, "www.example.com", :body => "abc").
        should match(RequestProfile.new(:get, "www.example.com"))
    end
    
    it "should not match if other has nil body" do
      RequestSignature.new(:get, "www.example.com", :body => "abc").
        should_not match(RequestProfile.new(:get, "www.example.com", :body => nil))
    end

    it "should not match if other has empty body" do
      RequestSignature.new(:get, "www.example.com", :body => "abc").
        should_not match(RequestProfile.new(:get, "www.example.com", :body => ""))
    end
    
    it "should not match if other has body" do
      RequestSignature.new(:get, "www.example.com").
        should_not match(RequestProfile.new(:get, "www.example.com", :body => "abc"))
    end

    it "should match for same headers" do
      RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}).
        should match(RequestProfile.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}))
    end
    
    it "should match for header values matching regexp" do
      RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}).
        should match(RequestProfile.new(:get, "www.example.com", :headers => {'Content-Type' => %r{^image/jpeg$}}))
    end

    it "should not match for different values of the same header" do
      RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}).
        should_not match(RequestProfile.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/png'}))
    end
    
    it "should not match for header values not matching regexp" do
      RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpegx'}).
        should_not match(RequestProfile.new(:get, "www.example.com", :headers => {'Content-Type' => %r{^image\/jpeg$}}))
    end

    it "should match if request has more headers than other" do
      RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg', 'Content-Length' => '8888'}).
        should match(RequestProfile.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}))
    end

    it "should not match if request has less headers that the other and all match" do
      RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}).
        should_not match(RequestProfile.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg', 'Content-Length' => '8888'}))
    end

    it "should match even is header keys or values are in different format" do
      RequestSignature.new(:get, "www.example.com", :headers => {:ContentLength => 8888, 'content_type' => 'image/png'}).
        should match(RequestProfile.new(:get, "www.example.com", :headers => {'ContentLength' => '8888', 'Content-type' => 'image/png'}))
    end
    
    it "should match is other has not specified" do
      RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}).
        should match(RequestProfile.new(:get, "www.example.com"))
    end

    it "should not match is other has nil headers" do
      RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}).
        should match(RequestProfile.new(:get, "www.example.com", :headers => nil))
    end

    it "should not match if other has empty headers" do
      RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}).
        should_not match(RequestProfile.new(:get, "www.example.com", :headers => {}))
    end

    it "should not match if profile has no headers but other has headers" do
      RequestSignature.new(:get, "www.example.com").
        should_not match(RequestProfile.new(:get, "www.example.com", :headers => {'A'=>'a'}))
    end

    it "should not match if profile has empty headers but other has headers" do
      RequestSignature.new(:get, "www.example.com", :headers => {}).
        should_not match(RequestProfile.new(:get, "www.example.com", :headers => {'A'=>'a'}))
    end

  end

end
