require 'spec_helper'

describe WebMock::RequestPattern do

  describe "describing itself" do
    it "should report string describing itself" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com",
      :body => "abc", :headers => {'A' => 'a', 'B' => 'b'}).to_s).to eq(
        "GET http://www.example.com/ with body \"abc\" with headers {'A'=>'a', 'B'=>'b'}"
      )
    end

    it "should report string describing itself with block" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com",
      :body => "abc", :headers => {'A' => 'a', 'B' => 'b'}).with {|req| true}.to_s).to eq(
        "GET http://www.example.com/ with body \"abc\" with headers {'A'=>'a', 'B'=>'b'} with given block"
      )
    end

    it "should report string describing itself with query params" do
      expect(WebMock::RequestPattern.new(:get, /.*example.*/, :query => {'a' => ['b', 'c']}).to_s).to eq(
        "GET /.*example.*/ with query params {\"a\"=>[\"b\", \"c\"]}"
      )
    end

    it "should report string describing itself with query params as hash including matcher" do
      expect(WebMock::RequestPattern.new(:get, /.*example.*/,
      :query => WebMock::Matchers::HashIncludingMatcher.new({'a' => ['b', 'c']})).to_s).to eq(
        "GET /.*example.*/ with query params hash_including({\"a\"=>[\"b\", \"c\"]})"
      )
    end

    it "should report string describing itself with body as hash including matcher" do
      expect(WebMock::RequestPattern.new(:get, /.*example.*/,
      :body => WebMock::Matchers::HashIncludingMatcher.new({'a' => ['b', 'c']})).to_s).to eq(
        "GET /.*example.*/ with body hash_including({\"a\"=>[\"b\", \"c\"]})"
      )
    end
  end

  describe "with" do
    before(:each) do
      @request_pattern =WebMock::RequestPattern.new(:get, "www.example.com")
    end

    it "should have assigned body pattern" do
      @request_pattern.with(:body => "abc")
      expect(@request_pattern.to_s).to eq(WebMock::RequestPattern.new(:get, "www.example.com", :body => "abc").to_s)
    end

    it "should have assigned normalized headers pattern" do
      @request_pattern.with(:headers => {'A' => 'a'})
      expect(@request_pattern.to_s).to eq(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {'A' => 'a'}).to_s)
    end

    it "should raise an error if options passed to `with` are invalid" do
      expect { @request_pattern.with(:foo => "bar") }.to raise_error('Unknown key: "foo". Valid keys are: "body", "headers", "query"')
    end

    it "should raise an error if neither options or block is provided" do
      expect { @request_pattern.with() }.to raise_error('#with method invoked with no arguments. Either options hash or block must be specified.')
    end
  end


  class WebMock::RequestPattern
    def match(request_signature)
      self.matches?(request_signature)
    end
  end

  describe "when matching" do

    it "should match if uri matches and method matches" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com")).
        to match(WebMock::RequestSignature.new(:get, "www.example.com"))
    end

    it "should match if uri matches and method pattern is any" do
      expect(WebMock::RequestPattern.new(:any, "www.example.com")).
        to match(WebMock::RequestSignature.new(:get, "www.example.com"))
    end

    it "should not match if request has different method" do
      expect(WebMock::RequestPattern.new(:post, "www.example.com")).
        not_to match(WebMock::RequestSignature.new(:get, "www.example.com"))
    end

    it "should match if uri matches request uri" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com")).
        to match(WebMock::RequestSignature.new(:get, "www.example.com"))
    end

    it "should match if request has unescaped uri" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com/my%20path")).
        to match(WebMock::RequestSignature.new(:get, "www.example.com/my path"))
    end

    it "should match if request has escaped uri" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com/my path")).
        to match(WebMock::RequestSignature.new(:get, "www.example.com/my%20path"))
    end

    it "should match if uri regexp pattern matches unescaped form of request uri" do
      expect(WebMock::RequestPattern.new(:get, /.*my path.*/)).
        to match(WebMock::RequestSignature.new(:get, "www.example.com/my%20path"))
    end

    it "should match if uri regexp pattern matches request uri" do
      expect(WebMock::RequestPattern.new(:get, /.*example.*/)).
        to match(WebMock::RequestSignature.new(:get, "www.example.com"))
    end

    it "should match if uri Addressable::Template pattern matches unescaped form of request uri" do
      expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com/{any_path}"))).
        to match(WebMock::RequestSignature.new(:get, "www.example.com/my%20path"))
    end

    it "should match if uri Addressable::Template pattern matches request uri" do
      expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com"))).
        to match(WebMock::RequestSignature.new(:get, "www.example.com"))
    end

    it "should match for uris with same parameters as pattern" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com?a=1&b=2")).
        to match(WebMock::RequestSignature.new(:get, "www.example.com?a=1&b=2"))
    end

    it "should not match for uris with different parameters" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com?a=1&b=2")).
        not_to match(WebMock::RequestSignature.new(:get, "www.example.com?a=2&b=1"))
    end

    it "should match for uri parameters in different order" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com?b=2&a=1")).
        to match(WebMock::RequestSignature.new(:get, "www.example.com?a=1&b=2"))
    end

    describe "when parameters are escaped" do

      it "should match if uri pattern has escaped parameters and request has unescaped parameters" do
        expect(WebMock::RequestPattern.new(:get, "www.example.com/?a=a%20b")).
          to match(WebMock::RequestSignature.new(:get, "www.example.com/?a=a b"))
      end

      it "should match if uri pattern has unescaped parameters and request has escaped parameters" do
        expect(WebMock::RequestPattern.new(:get, "www.example.com/?a=a b")).
          to match(WebMock::RequestSignature.new(:get, "www.example.com/?a=a%20b"))
      end

      it "should match if uri regexp pattern matches uri with unescaped parameters and request has escaped parameters" do
        expect(WebMock::RequestPattern.new(:get, /.*a=a b.*/)).
          to match(WebMock::RequestSignature.new(:get, "www.example.com/?a=a%20b"))
      end

      it "should match if uri regexp pattern matches uri with escaped parameters and request has unescaped parameters"  do
        expect(WebMock::RequestPattern.new(:get, /.*a=a%20b.*/)).
          to match(WebMock::RequestSignature.new(:get, "www.example.com/?a=a b"))
      end

      it "should match if uri Addressable::Template pattern matches uri without parameter value and request has escaped parameters" do
        expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com/{?a}"))).
          to match(WebMock::RequestSignature.new(:get, "www.example.com/?a=a%20b"))
      end

      it "should match if uri Addressable::Template pattern matches uri without parameter value and request has unescaped parameters"  do
        expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com/{?a}"))).
          to match(WebMock::RequestSignature.new(:get, "www.example.com/?a=a b"))
      end

      it "should match if uri Addressable::Template pattern matches uri with unescaped parameter value and request has unescaped parameters"  do
        expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com/?a=a b"))).
          to match(WebMock::RequestSignature.new(:get, "www.example.com/?a=a b"))
      end

      it "should match if uri Addressable::Template pattern matches uri with escaped parameter value and request has escaped parameters"  do
        expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com/?a=a%20b"))).
          to match(WebMock::RequestSignature.new(:get, "www.example.com/?a=a%20b"))
      end

    end

    describe "when matching requests on query params" do

      describe "when uri is described as regexp" do
        it "should match request query params" do
          expect(WebMock::RequestPattern.new(:get, /.*example.*/, :query => {"a" => ["b", "c"]})).
            to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c"))
        end

        it "should match request query params if params don't match" do
          expect(WebMock::RequestPattern.new(:get, /.*example.*/, :query => {"x" => ["b", "c"]})).
            not_to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c"))
        end

        it "should match when query params are declared as HashIncluding matcher matching params" do
          expect(WebMock::RequestPattern.new(:get, /.*example.*/,
          :query => WebMock::Matchers::HashIncludingMatcher.new({"a" => ["b", "c"]}))).
            to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end

        it "should not match when query params are declared as HashIncluding matcher not matching params" do
          expect(WebMock::RequestPattern.new(:get, /.*example.*/,
          :query => WebMock::Matchers::HashIncludingMatcher.new({"x" => ["b", "c"]}))).
            not_to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end

        it "should match when query params are declared as RSpec HashIncluding matcher matching params" do
          expect(WebMock::RequestPattern.new(:get, /.*example.*/,
          :query => RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher.new({"a" => ["b", "c"]}))).
            to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end

        it "should not match when query params are declared as RSpec HashIncluding matcher not matching params" do
          expect(WebMock::RequestPattern.new(:get, /.*example.*/,
          :query => RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher.new({"a" => ["b", "d"]}))).
            not_to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end
      end

      describe "when uri is described as Addressable::Template" do
        it "should raise error if query params are specified" do
          expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com"), :query => {"a" => ["b", "c"]})).
            to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c"))
        end

        it "should match request query params if params don't match" do
          expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com"), :query => {"x" => ["b", "c"]})).
            not_to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c"))
        end

        it "should match when query params are declared as HashIncluding matcher matching params" do
          expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com"),
          :query => WebMock::Matchers::HashIncludingMatcher.new({"a" => ["b", "c"]}))).
            to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end

        it "should not match when query params are declared as HashIncluding matcher not matching params" do
          expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com"),
          :query => WebMock::Matchers::HashIncludingMatcher.new({"x" => ["b", "c"]}))).
            not_to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end

        it "should match when query params are declared as RSpec HashIncluding matcher matching params" do
          expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com"),
          :query => RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher.new({"a" => ["b", "c"]}))).
            to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end

        it "should not match when query params are declared as RSpec HashIncluding matcher not matching params" do
          expect(WebMock::RequestPattern.new(:get, Addressable::Template.new("www.example.com"),
          :query => RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher.new({"a" => ["b", "d"]}))).
            not_to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end
      end

      describe "when uri is described as string" do
        it "should match when query params are the same as declared in hash" do
          expect(WebMock::RequestPattern.new(:get, "www.example.com", :query => {"a" => ["b", "c"]})).
            to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c"))
        end

        it "should not match when query params are different than the declared in hash" do
          expect(WebMock::RequestPattern.new(:get, "www.example.com", :query => {"a" => ["b", "c"]})).
            not_to match(WebMock::RequestSignature.new(:get, "www.example.com?x[]=b&a[]=c"))
        end

        it "should match when query params are the same as declared as string" do
          expect(WebMock::RequestPattern.new(:get, "www.example.com", :query => "a[]=b&a[]=c")).
            to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c"))
        end

        it "should match when query params are the same as declared both in query option or url" do
          expect(WebMock::RequestPattern.new(:get, "www.example.com/?x=3", :query => "a[]=b&a[]=c")).
            to match(WebMock::RequestSignature.new(:get, "www.example.com/?x=3&a[]=b&a[]=c"))
        end

        it "should match when query params are declared as HashIncluding matcher matching params" do
          expect(WebMock::RequestPattern.new(:get, "www.example.com",
          :query => WebMock::Matchers::HashIncludingMatcher.new({"a" => ["b", "c"]}))).
            to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end

        it "should not match when query params are declared as HashIncluding matcher not matching params" do
          expect(WebMock::RequestPattern.new(:get, "www.example.com",
          :query => WebMock::Matchers::HashIncludingMatcher.new({"x" => ["b", "c"]}))).
            not_to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end

        it "should match when query params are declared as RSpec HashIncluding matcher matching params" do
          expect(WebMock::RequestPattern.new(:get, "www.example.com",
          :query => RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher.new({"a" => ["b", "c"]}))).
            to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end

        it "should not match when query params are declared as RSpec HashIncluding matcher not matching params" do
          expect(WebMock::RequestPattern.new(:get, "www.example.com",
          :query => RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher.new({"a" => ["b", "d"]}))).
            not_to match(WebMock::RequestSignature.new(:get, "www.example.com?a[]=b&a[]=c&b=1"))
        end

        context "when using query values notation as flat array" do
          before :all do
            WebMock::Config.instance.query_values_notation = :flat_array
          end

          it "should not match when repeated query params are not the same as declared as string" do
            expect(WebMock::RequestPattern.new(:get, "www.example.com", :query => "a=b&a=c")).
              to match(WebMock::RequestSignature.new(:get, "www.example.com?a=b&a=c"))
          end

          after :all do
            WebMock::Config.instance.query_values_notation = nil
          end
        end
      end
    end

    describe "when matching requests with body" do

      it "should match if request body and body pattern are the same" do
        expect(WebMock::RequestPattern.new(:get, "www.example.com", :body => "abc")).
          to match(WebMock::RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should match if request body matches regexp" do
        expect(WebMock::RequestPattern.new(:get, "www.example.com", :body => /^abc$/)).
          to match(WebMock::RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should not match if body pattern is different than request body" do
        expect(WebMock::RequestPattern.new(:get, "www.example.com", :body => "def")).
          not_to match(WebMock::RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should not match if request body doesn't match regexp pattern" do
        expect(WebMock::RequestPattern.new(:get, "www.example.com", :body => /^abc$/)).
          not_to match(WebMock::RequestSignature.new(:get, "www.example.com", :body => "xabc"))
      end

      it "should match if pattern doesn't have specified body" do
        expect(WebMock::RequestPattern.new(:get, "www.example.com")).
          to match(WebMock::RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should not match if pattern has body specified as nil but request body is not empty" do
        expect(WebMock::RequestPattern.new(:get, "www.example.com", :body => nil)).
          not_to match(WebMock::RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should not match if pattern has empty body but request body is not empty" do
        expect(WebMock::RequestPattern.new(:get, "www.example.com", :body => "")).
          not_to match(WebMock::RequestSignature.new(:get, "www.example.com", :body => "abc"))
      end

      it "should not match if pattern has body specified but request has no body" do
        expect(WebMock::RequestPattern.new(:get, "www.example.com", :body => "abc")).
          not_to match(WebMock::RequestSignature.new(:get, "www.example.com"))
      end

      describe "when body in pattern is declared as a hash" do
        let(:body_hash) { {:a => '1', :b => 'five', 'c' => {'d' => ['e', 'f']}} }

        describe "for request with url encoded body" do
          it "should match when hash matches body" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              to match(WebMock::RequestSignature.new(:post, "www.example.com", :body => 'a=1&c[d][]=e&c[d][]=f&b=five'))
          end

          it "should match when hash matches body in different order of params" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              to match(WebMock::RequestSignature.new(:post, "www.example.com", :body => 'a=1&c[d][]=e&b=five&c[d][]=f'))
          end

          it "should not match when hash doesn't match url encoded body" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              not_to match(WebMock::RequestSignature.new(:post, "www.example.com", :body => 'c[d][]=f&a=1&c[d][]=e'))
          end

          it "should not match when body is not url encoded" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              not_to match(WebMock::RequestSignature.new(:post, "www.example.com", :body => 'foo bar'))
          end

          it "should match when hash contains regex values" do
            expect(WebMock::RequestPattern.new(:post, "www.example.com", :body => {:a => /^\w{5}$/, :b => {:c => /^\d{3}$/}})).
              to match(WebMock::RequestSignature.new(:post, "www.example.com", :body => 'a=abcde&b[c]=123'))
          end

          it "should not match when hash does not contains regex values" do
            expect(WebMock::RequestPattern.new(:post, "www.example.com", :body => {:a => /^\d+$/, :b => {:c => /^\d{3}$/}})).
              not_to match(WebMock::RequestSignature.new(:post, "www.example.com", :body => 'a=abcde&b[c]=123'))
          end

          context 'body is an hash with an array of hashes' do
            let(:body_hash) { {:a => [{'b' => '1'}, {'b' => '2'}]} }

            it "should match when hash matches body" do
              expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
                to match(WebMock::RequestSignature.new(:post, "www.example.com", :body => 'a[][b]=1&a[][b]=2'))
            end
          end

          context 'body is an hash with an array of hashes with multiple keys' do
            let(:body_hash) { {:a => [{'b' => '1', 'a' => '2'}, {'b' => '3'}]} }

            it "should match when hash matches body" do
              expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
                to match(WebMock::RequestSignature.new(:post, "www.example.com", :body => 'a[][b]=1&a[][a]=2&a[][b]=3'))
            end
          end
        end

        describe "for request with json body and content type is set to json" do
          it "should match when hash matches body" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              to match(WebMock::RequestSignature.new(:post, "www.example.com", :headers => {:content_type => 'application/json'},
                                                         :body => "{\"a\":\"1\",\"c\":{\"d\":[\"e\",\"f\"]},\"b\":\"five\"}"))
              end

          it "should match if hash matches body in different form" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              to match(WebMock::RequestSignature.new(:post, "www.example.com", :headers => {:content_type => 'application/json'},
                                                         :body => "{\"a\":\"1\",\"b\":\"five\",\"c\":{\"d\":[\"e\",\"f\"]}}"))
              end

          it "should not match when body is not json" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              not_to match(WebMock::RequestSignature.new(:post, "www.example.com",
                                                             :headers => {:content_type => 'application/json'}, :body => "foo bar"))
          end

          it "should not match if request body is different" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => {:a => 1, :b => 2})).
              not_to match(WebMock::RequestSignature.new(:post, "www.example.com",
              :headers => {:content_type => 'application/json'}, :body => "{\"a\":1,\"c\":null}"))
          end

          it "should not match if request body is has less params than pattern" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => {:a => 1, :b => 2})).
              not_to match(WebMock::RequestSignature.new(:post, "www.example.com",
              :headers => {:content_type => 'application/json'}, :body => "{\"a\":1}"))
          end

          it "should not match if request body is has more params than pattern" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => {:a => 1})).
              not_to match(WebMock::RequestSignature.new(:post, "www.example.com",
              :headers => {:content_type => 'application/json'}, :body => "{\"a\":1,\"c\":1}"))
          end
        end

        describe "for request with xml body and content type is set to xml" do
          let(:body_hash) { {"opt" => {:a => '1', :b => 'five', 'c' => {'d' => ['e', 'f']}}} }

          it "should match when hash matches body" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              to match(WebMock::RequestSignature.new(:post, "www.example.com", :headers => {:content_type => 'application/xml'},
                                                         :body => "<opt a=\"1\" b=\"five\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n"))
              end

          it "should match if hash matches body in different form" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              to match(WebMock::RequestSignature.new(:post, "www.example.com", :headers => {:content_type => 'application/xml'},
                                                         :body => "<opt b=\"five\" a=\"1\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n"))
              end

          it "should not match when body is not xml" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              not_to match(WebMock::RequestSignature.new(:post, "www.example.com",
                                                             :headers => {:content_type => 'application/xml'}, :body => "foo bar"))
              end

          it "matches when the content type include a charset" do
            expect(WebMock::RequestPattern.new(:post, 'www.example.com', :body => body_hash)).
              to match(WebMock::RequestSignature.new(:post, "www.example.com", :headers => {:content_type => 'application/xml;charset=UTF-8'},
                                                         :body => "<opt a=\"1\" b=\"five\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n"))

          end
        end
      end

      describe "when body in a pattern is declared as a partial hash matcher" do
        let(:signature) { WebMock::RequestSignature.new(:post, "www.example.com", :body => 'a=1&c[d][]=e&c[d][]=f&b=five') }

       it "should match when query params are declared as HashIncluding matcher matching params" do
          expect(WebMock::RequestPattern.new(:post, "www.example.com",
          :body => WebMock::Matchers::HashIncludingMatcher.new({:a => '1', 'c' => {'d' => ['e', 'f']}}))).
            to match(signature)
        end

        it "should not match when query params are declared as HashIncluding matcher not matching params" do
          expect(WebMock::RequestPattern.new(:post, "www.example.com",
          :body => WebMock::Matchers::HashIncludingMatcher.new({:x => '1', 'c' => {'d' => ['e', 'f']}}))).
            not_to match(signature)
        end

        it "should match when query params are declared as RSpec HashIncluding matcher matching params" do
          expect(WebMock::RequestPattern.new(:post, "www.example.com",
          :body => RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher.new({:a => '1', 'c' => {'d' => ['e', 'f']}}))).
            to match(signature)
        end

        it "should not match when query params are declared as RSpec HashIncluding matcher not matching params" do
          expect(WebMock::RequestPattern.new(:post, "www.example.com",
          :body => RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher.new({:x => '1', 'c' => {'d' => ['e', 'f']}}))).
            not_to match(signature)
        end
      end
    end

    it "should match if pattern and request have the same headers" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'})).
        to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}))
    end

    it "should match if pattern headers values are regexps matching request header values" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => %r{^image/jpeg$}})).
        to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}))
    end

    it "should not match if pattern has different value of header than request" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/png'})).
        not_to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}))
    end

    it "should not match if pattern header value regexp doesn't match request header value" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => %r{^image\/jpeg$}})).
        not_to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpegx'}))
    end

    it "should match if request has more headers than request pattern" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'})).
        to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg', 'Content-Length' => '8888'}))
    end

    it "should not match if request has less headers than the request pattern" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg', 'Content-Length' => '8888'})).
        not_to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {'Content-Type' => 'image/jpeg'}))
    end

    it "should match even is header keys are declared in different form" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {'ContentLength' => '8888', 'Content-type' => 'image/png'})).
        to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {:ContentLength => 8888, 'content_type' => 'image/png'}))
    end

    it "should match is pattern doesn't have specified headers" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com")).
        to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}))
    end

    it "should not match if pattern has nil headers but request has headers" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => nil)).
        not_to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}))
    end

    it "should not match if pattern has empty headers but request has headers" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {})).
        not_to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}))
    end

    it "should not match if pattern has specified headers but request has nil headers" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {'A'=>'a'})).
        not_to match(WebMock::RequestSignature.new(:get, "www.example.com"))
    end

    it "should not match if pattern has specified headers but request has empty headers" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com", :headers => {'A'=>'a'})).
        not_to match(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {}))
    end

    it "should match if block given in pattern evaluates request to true" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com").with { |request| true }).
        to match(WebMock::RequestSignature.new(:get, "www.example.com"))
    end

    it "should not match if block given in pattrn evaluates request to false" do
      expect(WebMock::RequestPattern.new(:get, "www.example.com").with { |request| false }).
        not_to match(WebMock::RequestSignature.new(:get, "www.example.com"))
    end

    it "should yield block with request signature" do
      signature = WebMock::RequestSignature.new(:get, "www.example.com")
      expect(WebMock::RequestPattern.new(:get, "www.example.com").with { |request| request == signature }).
        to match(signature)
    end

  end


end
