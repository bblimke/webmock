require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RequestPattern do

  it "should report string describing itself" do
    RequestPattern.new(:get, "www.example.com",
      :body => "abc", :headers => {'A' => 'a', 'B' => 'b'}).to_s.should ==
    "GET http://www.example.com/ with body \"abc\" with headers {'A'=>'a', 'B'=>'b'}"
  end

  it "should report string describing itself with block" do
    RequestPattern.new(:get, "www.example.com",
      :body => "abc", :headers => {'A' => 'a', 'B' => 'b'}).with {|req| true}.to_s.should ==
    "GET http://www.example.com/ with body \"abc\" with headers {'A'=>'a', 'B'=>'b'} with given block"
  end
  
  it "should report string describing itself with query params" do
    RequestPattern.new(:get, /.*example.*/, :query => {'a' => ['b', 'c']}).to_s.should ==
    "GET /.*example.*/ with query params {\"a\"=>[\"b\", \"c\"]}"
  end

  describe "with" do
    before(:each) do
      @request_pattern = RequestPattern.new(:get, "www.example.com")
    end

    it "should have assigned body pattern" do
      @request_pattern.with(:body => "abc")
      @request_pattern.to_s.should == RequestPattern.new(:get, "www.example.com", :body => "abc").to_s
    end

    it "should have assigned normalized headers pattern" do
      @request_pattern.with(:headers => {'A' => 'a'})
      @request_pattern.to_s.should == RequestPattern.new(:get, "www.example.com", :headers => {'A' => 'a'}).to_s
    end

  end


  class WebMock::RequestPattern
    def match(request_signature)
      self.matches?(request_signature)
    end
  end

  describe "when matching" do

    it "should match if uri matches and method matches" do
      RequestPattern.new(:get, "www.example.com").
        should match(RequestSignature.new(:get, "www.example.com"))
    end

    it "should match if uri matches and method pattern is any" do
      RequestPattern.new(:any, "www.example.com").
        should match(RequestSignature.new(:get, "www.example.com"))
    end

    it "should not match if request has different method" do
      RequestPattern.new(:post, "www.example.com").
        should_not match(RequestSignature.new(:get, "www.example.com"))
    end

    it "should match if uri matches request uri" do
      RequestPattern.new(:get, "www.example.com").
        should match(RequestSignature.new(:get, "www.example.com"))
    end

    it "should match if request has unescaped uri" do
      RequestPattern.new(:get, "www.example.com/my%20path").
        should match(RequestSignature.new(:get, "www.example.com/my path"))
    end

    it "should match if request has escaped uri" do
      RequestPattern.new(:get, "www.example.com/my path").
        should match(RequestSignature.new(:get, "www.example.com/my%20path"))
    end

    it "should match if uri regexp pattern matches unescaped form of request uri" do
      RequestPattern.new(:get, /.*my path.*/).
        should match(RequestSignature.new(:get, "www.example.com/my%20path"))
    end

    it "should match if uri regexp pattern matches request uri" do
      RequestPattern.new(:get, /.*example.*/).
        should match(RequestSignature.new(:get, "www.example.com"))
    end

    it "should match for uris with same parameters as pattern" do
      RequestPattern.new(:get, "www.example.com?a=1&b=2").
        should match(RequestSignature.new(:get, "www.example.com?a=1&b=2"))
    end

    it "should not match for uris with different parameters" do
      RequestPattern.new(:get, "www.example.com?a=1&b=2").
        should_not match(RequestSignature.new(:get, "www.example.com?a=2&b=1"))
    end

    it "should match for uri parameters in different order" do
      RequestPattern.new(:get, "www.example.com?b=2&a=1").
        should match(RequestSignature.new(:get, "www.example.com?a=1&b=2"))
    end

    describe "when parameters are escaped" do

      it "should match if uri pattern has escaped parameters and request has unescaped parameters" do
        RequestPattern.new(:get, "www.example.com/?a=a%20b").
          should match(RequestSignature.new(:get, "www.example.com/?a=a b"))
      end

      it "should match if uri pattern has unescaped parameters and request has escaped parameters" do
        RequestPattern.new(:get, "www.example.com/?a=a b").
          should match(RequestSignature.new(:get, "www.example.com/?a=a%20b"))
      end

      it "should match if uri regexp pattern matches uri with unescaped parameters and request has escaped parameters" do
        RequestPattern.new(:get, /.*a=a b.*/).
          should match(RequestSignature.new(:get, "www.example.com/?a=a%20b"))
      end

      it "should match if uri regexp pattern matches uri with escaped parameters and request has unescaped parameters"  do
        RequestPattern.new(:get, /.*a=a%20b.*/).
          should match(RequestSignature.new(:get, "www.example.com/?a=a b"))
      end

    end

    describe "when matching requests on query params" do

      it "should match request query params even if uri is declared as regexp" do
        RequestPattern.new(:get, /.*example.*/, :query => {"a" => ["b", "c"]}).
          should match(RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c"))
      end

      it "should match request query params if uri is declared as regexp but params don't match" do
        RequestPattern.new(:get, /.*example.*/, :query => {"x" => ["b", "c"]}).
          should_not match(RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c"))
      end

      it "should match for query params are the same as declared in hash" do
        RequestPattern.new(:get, "www.example.com", :query => {"a" => ["b", "c"]}).
          should match(RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c"))
      end
      
      it "should not match for query params are different than the declared in hash" do
        RequestPattern.new(:get, "www.example.com", :query => {"a" => ["b", "c"]}).
          should_not match(RequestSignature.new(:get, "www.example.com?x[]=b&a[]=c"))
      end

      it "should match for query params are the same as declared as string" do
        RequestPattern.new(:get, "www.example.com", :query => "a[]=b&a[]=c").
          should match(RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c"))
      end

      it "should match for query params are the same as declared both in query option or url" do
        RequestPattern.new(:get, "www.example.com/?x=3", :query => "a[]=b&a[]=c").
          should match(RequestSignature.new(:get, "www.example.com/?x=3&a[]=b&a[]=c"))
      end

    end

    describe "when matching requests with body" do

      it "should match if request body and body pattern are the same" do
        RequestPattern.new(:get, "www.example.com", :body => "abc").
          should match(RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should match if request body matches regexp" do
        RequestPattern.new(:get, "www.example.com", :body => /^abc$/).
          should match(RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should not match if body pattern is different than request body" do
        RequestPattern.new(:get, "www.example.com", :body => "def").
          should_not match(RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should not match if request body doesn't match regexp pattern" do
        RequestPattern.new(:get, "www.example.com", :body => /^abc$/).
          should_not match(RequestSignature.new(:get, "www.example.com", :body => "xabc"))
      end

      it "should match if pattern doesn't have specified body" do
        RequestPattern.new(:get, "www.example.com").
          should match(RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should not match if pattern has body specified as nil but request body is not empty" do
        RequestPattern.new(:get, "www.example.com", :body => nil).
          should_not match(RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should not match if pattern has empty body but request body is not empty" do
        RequestPattern.new(:get, "www.example.com", :body => "").
          should_not match(RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should not match if pattern has body specified but request has no body" do
        RequestPattern.new(:get, "www.example.com", :body => "abc").
          should_not match(RequestSignature.new(:get, "www.example.com"))
      end

      describe "when body in pattern is declared as a hash" do
        let(:body_hash) { {:a => '1', :b => 'five', 'c' => {'d' => ['e', 'f']}} }

        describe "for request with url encoded body" do
          it "should match when hash matches body" do
            RequestPattern.new(:post, 'www.example.com', :body => body_hash).
              should match(RequestSignature.new(:post, "www.example.com", :body => 'a=1&c[d][]=e&c[d][]=f&b=five'))
          end

          it "should match when hash matches body in different order of params" do
            RequestPattern.new(:post, 'www.example.com', :body => body_hash).
              should match(RequestSignature.new(:post, "www.example.com", :body => 'a=1&c[d][]=e&b=five&c[d][]=f'))
          end

          it "should not match when hash doesn't match url encoded body" do
            RequestPattern.new(:post, 'www.example.com', :body => body_hash).
              should_not match(RequestSignature.new(:post, "www.example.com", :body => 'c[d][]=f&a=1&c[d][]=e'))
          end

          it "should not match when body is not url encoded" do
            RequestPattern.new(:post, 'www.example.com', :body => body_hash).
              should_not match(RequestSignature.new(:post, "www.example.com", :body => 'foo bar'))
          end

        end

        describe "for request with json body and content type is set to json" do
          it "should match when hash matches body" do
            RequestPattern.new(:post, 'www.example.com', :body => body_hash).
              should match(RequestSignature.new(:post, "www.example.com", :headers => {:content_type => 'application/json'},
              :body => "{\"a\":\"1\",\"c\":{\"d\":[\"e\",\"f\"]},\"b\":\"five\"}"))
          end

          it "should match if hash matches body in different form" do
            RequestPattern.new(:post, 'www.example.com', :body => body_hash).
              should match(RequestSignature.new(:post, "www.example.com", :headers => {:content_type => 'application/json'},
              :body => "{\"a\":\"1\",\"b\":\"five\",\"c\":{\"d\":[\"e\",\"f\"]}}"))
          end

          it "should not match when body is not json" do
            RequestPattern.new(:post, 'www.example.com', :body => body_hash).
              should_not match(RequestSignature.new(:post, "www.example.com",
              :headers => {:content_type => 'application/json'}, :body => "foo bar"))
          end
        end

        describe "for request with xml body and content type is set to xml" do
          let(:body_hash) { {"opt" => {:a => '1', :b => 'five', 'c' => {'d' => ['e', 'f']}}} }

          it "should match when hash matches body" do
            RequestPattern.new(:post, 'www.example.com', :body => body_hash).
              should match(RequestSignature.new(:post, "www.example.com", :headers => {:content_type => 'application/xml'},
              :body => "<opt a=\"1\" b=\"five\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n"))
          end

          it "should match if hash matches body in different form" do
            RequestPattern.new(:post, 'www.example.com', :body => body_hash).
              should match(RequestSignature.new(:post, "www.example.com", :headers => {:content_type => 'application/xml'},
              :body => "<opt b=\"five\" a=\"1\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n"))
          end

          it "should not match when body is not xml" do
            RequestPattern.new(:post, 'www.example.com', :body => body_hash).
              should_not match(RequestSignature.new(:post, "www.example.com",
              :headers => {:content_type => 'application/xml'}, :body => "foo bar"))
          end
        end
      end
    end



    it "should match if pattern and request have the same headers" do
      RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}).
        should match(RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}))
    end

    it "should match if pattern headers values are regexps matching request header values" do
      RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => %r{^image/jpeg$}}).
        should match(RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}))
    end

    it "should not match if pattern has different value of header than request" do
      RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/png'}).
        should_not match(RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}))
    end

    it "should not match if pattern header value regexp doesn't match request header value" do
      RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => %r{^image\/jpeg$}}).
        should_not match(RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpegx'}))
    end

    it "should match if request has more headers than request pattern" do
      RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}).
        should match(RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg', 'Content-Length' => '8888'}))
    end

    it "should not match if request has less headers than the request pattern" do
      RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg', 'Content-Length' => '8888'}).
        should_not match(RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}))
    end

    it "should match even is header keys are declared in different form" do
      RequestPattern.new(:get, "www.example.com", :headers => {'ContentLength' => '8888', 'Content-type' => 'image/png'}).
        should match(RequestSignature.new(:get, "www.example.com", :headers => {:ContentLength => 8888, 'content_type' => 'image/png'}))
    end

    it "should match is pattern doesn't have specified headers" do
      RequestPattern.new(:get, "www.example.com").
        should match(RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}))
    end

    it "should not match if pattern has nil headers but request has headers" do
      RequestPattern.new(:get, "www.example.com", :headers => nil).
        should_not match(RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}))
    end

    it "should not match if pattern has empty headers but request has headers" do
      RequestPattern.new(:get, "www.example.com", :headers => {}).
        should_not match(RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}))
    end

    it "should not match if pattern has specified headers but request has nil headers" do
      RequestPattern.new(:get, "www.example.com", :headers => {'A'=>'a'}).
        should_not match(RequestSignature.new(:get, "www.example.com"))
    end

    it "should not match if pattern has specified headers but request has empty headers" do
      RequestPattern.new(:get, "www.example.com", :headers => {'A'=>'a'}).
        should_not match(RequestSignature.new(:get, "www.example.com", :headers => {}))
    end

    it "should match if block given in pattern evaluates request to true" do
      RequestPattern.new(:get, "www.example.com").with { |request| true }.
        should match(RequestSignature.new(:get, "www.example.com"))
    end

    it "should not match if block given in pattrn evaluates request to false" do
      RequestPattern.new(:get, "www.example.com").with { |request| false }.
        should_not match(RequestSignature.new(:get, "www.example.com"))
    end

    it "should yield block with request signature" do
      signature = RequestSignature.new(:get, "www.example.com")
      RequestPattern.new(:get, "www.example.com").with { |request| request == signature }.
        should match(signature)
    end

  end


end
