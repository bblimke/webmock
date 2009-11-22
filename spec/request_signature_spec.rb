require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

include WebMock

describe RequestSignature do

  describe "when matching" do

    it "should match if uri matches and method matches" do
      RequestSignature.new(:get, "www.google.com").
        should match(RequestProfile.new(:get, "www.google.com"))
    end

    it "should match if uri matches and method is any" do
      RequestSignature.new(:get, "www.google.com").
        should match(RequestProfile.new(:any, "www.google.com"))
    end

    it "should not match if other request profile has different method" do
      RequestSignature.new(:get, "www.google.com").
        should_not match(RequestProfile.new(:post, "www.google.com"))
    end

    it "should match if uri matches other uri" do
      RequestSignature.new(:get, "www.google.com").
        should match(RequestProfile.new(:get, "www.google.com"))
    end
    
    it "should match if uri matches other escaped using uri" do
      RequestSignature.new(:get, "www.google.com/big image.jpg").
        should match(RequestProfile.new(:get, "www.google.com/big%20image.jpg"))
    end
    
    it "should match if unescaped uri matches other uri" do
      RequestSignature.new(:get, "www.google.com/big%20image.jpg").
        should match(RequestProfile.new(:get, "www.google.com/big image.jpg"))
    end
    
    it "should match if unescaped uri matches other regexp uri" do
      RequestSignature.new(:get, "www.google.com/big%20image.jpg").
        should match(RequestProfile.new(:get, /.*big image.jpg.*/))
    end

    it "should match if uri matches other regex uri" do
      RequestSignature.new(:get, "www.google.com").
        should match(RequestProfile.new(:get, /.*google.*/))
    end

    it "should match for uris with same parameters" do
      RequestSignature.new(:get, "www.google.com?a=1&b=2").
        should match(RequestProfile.new(:get, "www.google.com?a=1&b=2"))
    end

    it "should not match for uris with different parameters" do
      RequestSignature.new(:get, "www.google.com?a=2&b=1").
        should_not match(RequestProfile.new(:get, "www.google.com?a=1&b=2"))
    end

    it "should match for parameters in different order" do
      RequestSignature.new(:get, "www.google.com?a=1&b=2").
        should match(RequestProfile.new(:get, "www.google.com?b=2&a=1"))
    end
    
    describe "when parameters are escaped" do
    
      it "should match if uri with non escaped parameters is the same as other uri with escaped parameters" do
        RequestSignature.new(:get, "www.google.com/?a=a b").
          should match(RequestProfile.new(:get, "www.google.com/?a=a%20b"))
      end
    
      it "should match if uri with escaped parameters is the same as other uri with non escaped parameters" do
        RequestSignature.new(:get, "www.google.com/?a=a%20b").
          should match(RequestProfile.new(:get, "www.google.com/?a=a b"))
      end
    
      it "should match if other regexp is for non escaped parameters but uri has escaped parameters" do
        RequestSignature.new(:get, "www.google.com/?a=a%20b").
          should match(RequestProfile.new(:get, /.*a=a b.*/))
      end
    
      it "should match if other regexp is for escaped parameters but uri has non escaped parameters"  do
        RequestSignature.new(:get, "www.google.com/?a=a b").
          should match(RequestProfile.new(:get, /.*a=a%20b.*/))
      end
    
    end
    
    

    it "should match for same bodies" do
      RequestSignature.new(:get, "www.google.com", "abc").
        should match(RequestProfile.new(:get, "www.google.com", "abc"))
    end

    it "should not match for different bodies" do
      RequestSignature.new(:get, "www.google.com", "abc").
        should_not match(RequestProfile.new(:get, "www.google.com", "def"))
    end

    it "should match is other has nil body" do
      RequestSignature.new(:get, "www.google.com", "abc").
        should match(RequestProfile.new(:get, "www.google.com", nil))
    end

    it "should not match if other has empty body" do
      RequestSignature.new(:get, "www.google.com", "abc").
        should_not match(RequestProfile.new(:get, "www.google.com", ""))
    end

    it "should match for same headers" do
      RequestSignature.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg').
        should match(RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg'))
    end

    it "should not match for different values of the same header" do
      RequestSignature.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg').
        should_not match(RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/png'))
    end

    it "should match if request has more headers than other" do
      RequestSignature.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg', 'Content-Length' => '8888').
        should match(RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg'))
    end

    it "should not match if request has less headers that the other and all match" do
      RequestSignature.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg').
        should_not match(RequestProfile.new(:get, "www.google.com", nil, 'Content-Type' => 'image/jpeg', 'Content-Length' => '8888'))
    end

    it "should match even is header keys or values are in different format" do
      RequestSignature.new(:get, "www.google.com", nil, :ContentLength => 8888, 'content_type' => 'image/png').
        should match(RequestProfile.new(:get, "www.google.com", nil, 'ContentLength' => '8888', 'Content-type' => 'image/png'))
    end

    it "should match is other has nil headers" do
      RequestSignature.new(:get, "www.google.com", nil, 'A' => 'a').
        should match(RequestProfile.new(:get, "www.google.com", nil, nil))
    end

    it "should not match if other has empty headers" do
      RequestSignature.new(:get, "www.google.com", nil, 'A' => 'a').
        should_not match(RequestProfile.new(:get, "www.google.com", nil, {}))
    end

    it "should not match if profile has no headers but other has headers" do
      RequestSignature.new(:get, "www.google.com", nil, nil).
        should_not match(RequestProfile.new(:get, "www.google.com", nil, {'A'=>'a'}))
    end

    it "should not match if profile has empty headers but other has headers" do
      RequestSignature.new(:get, "www.google.com", nil, {}).
        should_not match(RequestProfile.new(:get, "www.google.com", nil, {'A'=>'a'}))
    end

  end

end
