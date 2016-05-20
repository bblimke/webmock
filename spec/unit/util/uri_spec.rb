require 'spec_helper'


URIS_WITHOUT_PATH_OR_PARAMS =
[
  "www.example.com",
  "www.example.com/",
  "www.example.com:80",
  "www.example.com:80/",
  "http://www.example.com",
  "http://www.example.com/",
  "http://www.example.com:80",
  "http://www.example.com:80/"
].sort

URIS_WITHOUT_PATH_BUT_WITH_PARAMS =
[
  "www.example.com?a=b",
  "www.example.com/?a=b",
  "www.example.com:80?a=b",
  "www.example.com:80/?a=b",
  "http://www.example.com?a=b",
  "http://www.example.com/?a=b",
  "http://www.example.com:80?a=b",
  "http://www.example.com:80/?a=b"
].sort

URIS_WITH_AUTH =
[
  "a b:pass@www.example.com",
  "a b:pass@www.example.com/",
  "a b:pass@www.example.com:80",
  "a b:pass@www.example.com:80/",
  "http://a b:pass@www.example.com",
  "http://a b:pass@www.example.com/",
  "http://a b:pass@www.example.com:80",
  "http://a b:pass@www.example.com:80/",
  "a%20b:pass@www.example.com",
  "a%20b:pass@www.example.com/",
  "a%20b:pass@www.example.com:80",
  "a%20b:pass@www.example.com:80/",
  "http://a%20b:pass@www.example.com",
  "http://a%20b:pass@www.example.com/",
  "http://a%20b:pass@www.example.com:80",
  "http://a%20b:pass@www.example.com:80/"
].sort

URIS_WITH_PATH_AND_PARAMS =
[
  "www.example.com/my path/?a=my param&b=c d",
  "www.example.com/my%20path/?a=my%20param&b=c%20d",
  "www.example.com:80/my path/?a=my param&b=c d",
  "www.example.com:80/my%20path/?a=my%20param&b=c%20d",
  "http://www.example.com/my path/?a=my param&b=c d",
  "http://www.example.com/my%20path/?a=my%20param&b=c%20d",
  "http://www.example.com:80/my path/?a=my param&b=c d",
  "http://www.example.com:80/my%20path/?a=my%20param&b=c%20d",
  ].sort

URIS_WITH_DIFFERENT_PORT =
[
  "www.example.com:88",
  "www.example.com:88/",
  "http://www.example.com:88",
  "http://www.example.com:88/"
].sort


URIS_FOR_HTTPS =
[
  "https://www.example.com",
  "https://www.example.com/",
  "https://www.example.com:443",
  "https://www.example.com:443/"
].sort


describe WebMock::Util::URI do

  describe "reporting variations of uri" do

    it "should find all variations of the same uri for all variations of uri with params and path" do
      URIS_WITH_PATH_AND_PARAMS.each do |uri|
        expect(WebMock::Util::URI.variations_of_uri_as_strings(uri).sort).to eq(URIS_WITH_PATH_AND_PARAMS)
      end
    end

    it "should find all variations of the same uri for all variations of uri with params but without path" do
      URIS_WITHOUT_PATH_BUT_WITH_PARAMS.each do |uri|
        expect(WebMock::Util::URI.variations_of_uri_as_strings(uri).sort).to eq(URIS_WITHOUT_PATH_BUT_WITH_PARAMS)
      end
    end

    it "should find all variations of the same uri for all variations of uri without params or path" do
      URIS_WITHOUT_PATH_OR_PARAMS.each do |uri|
        expect(WebMock::Util::URI.variations_of_uri_as_strings(uri).sort).to eq(URIS_WITHOUT_PATH_OR_PARAMS)
      end
    end

    it "should find all variations of the same uri for all variations of uri with auth" do
      URIS_WITH_AUTH.each do |uri|
        expect(WebMock::Util::URI.variations_of_uri_as_strings(uri).sort).to eq(URIS_WITH_AUTH)
      end
    end

    it "should find all variations of the same uri for all variations of uri with different port" do
      URIS_WITH_DIFFERENT_PORT.each do |uri|
        expect(WebMock::Util::URI.variations_of_uri_as_strings(uri).sort).to eq(URIS_WITH_DIFFERENT_PORT)
      end
    end

    it "should find all variations of the same uri for all variations of https uris" do
      URIS_FOR_HTTPS.each do |uri|
        expect(WebMock::Util::URI.variations_of_uri_as_strings(uri).sort).to eq(URIS_FOR_HTTPS)
      end
    end

  end

  describe "normalized uri equality" do

    it "should successfully compare all variations of the same uri with path and params" do
      URIS_WITH_PATH_AND_PARAMS.each do |uri_a|
        URIS_WITH_PATH_AND_PARAMS.each do |uri_b|
          expect(WebMock::Util::URI.normalize_uri(uri_a)).to be ===  WebMock::Util::URI.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same uri with path but with params" do
      URIS_WITHOUT_PATH_BUT_WITH_PARAMS.each do |uri_a|
        URIS_WITHOUT_PATH_BUT_WITH_PARAMS.each do |uri_b|
          expect(WebMock::Util::URI.normalize_uri(uri_a)).to be ===  WebMock::Util::URI.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same uri without path or params" do
      URIS_WITHOUT_PATH_OR_PARAMS.each do |uri_a|
        URIS_WITHOUT_PATH_OR_PARAMS.each do |uri_b|
          expect(WebMock::Util::URI.normalize_uri(uri_a)).to be ===  WebMock::Util::URI.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same uri with authority" do
      URIS_WITH_AUTH.each do |uri_a|
        URIS_WITH_AUTH.each do |uri_b|
          expect(WebMock::Util::URI.normalize_uri(uri_a)).to be ===  WebMock::Util::URI.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same uri custom port" do
      URIS_WITH_DIFFERENT_PORT.each do |uri_a|
        URIS_WITH_DIFFERENT_PORT.each do |uri_b|
          expect(WebMock::Util::URI.normalize_uri(uri_a)).to be ===  WebMock::Util::URI.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same https uri" do
      URIS_FOR_HTTPS.each do |uri_a|
        URIS_FOR_HTTPS.each do |uri_b|
          expect(WebMock::Util::URI.normalize_uri(uri_a)).to be ===  WebMock::Util::URI.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully handle array parameters" do
      uri_string = 'http://www.example.com:80/path?a[]=b&a[]=c'
      uri = WebMock::Util::URI.normalize_uri(uri_string)
      expect(WebMock::Util::QueryMapper.query_to_values(uri.query)).to eq({"a"=>["b", "c"]})
    end

    it "should successfully handle hash parameters" do
      uri_string = 'http://www.example.com:80/path?a[d]=b&a[e]=c&a[b][c]=1'
      uri = WebMock::Util::URI.normalize_uri(uri_string)
      expect(WebMock::Util::QueryMapper.query_to_values(uri.query)).to eq({"a"=>{"d"=>"b", "e"=>"c", "b"=>{"c"=>"1"}}})
    end

    it "should successfully handle nested hash parameters" do
      uri_string = 'http://www.example.com:80/path?one[two][three][]=four&one[two][three][]=five'
      uri = WebMock::Util::URI.normalize_uri(uri_string)
      expect(WebMock::Util::QueryMapper.query_to_values(uri.query)).to eq({"one"=>{"two"=>{"three" => ["four", "five"]}}})
    end

    it "should successfully handle mixed array and hash parameters" do
      # derived from an elasticsearch query:
      # load => {
      #   :include => [
      #     { :staff => :email },
      #     :business_name
      #   ]
      # }
      uri_string = "http://www.example.com:80/path?load[include][][staff]=email&load[include][]=business_name"
      uri = WebMock::Util::URI.normalize_uri(uri_string)
      expect(WebMock::Util::QueryMapper.query_to_values(uri.query)).to eq({"load"=>{"include"=>[{"staff"=>"email"},"business_name"]}})
    end

    context "when query notation is set to :flat_array" do
      before :all do
        WebMock::Config.instance.query_values_notation = :flat_array
      end

      it "should successfully handle repeated paramters" do
        uri_string = "http://www.example.com:80/path?target=host1&target=host2"
        uri = WebMock::Util::URI.normalize_uri(uri_string)
        expect(WebMock::Util::QueryMapper.query_to_values(uri.query, notation: WebMock::Config.instance.query_values_notation)).to eq([['target', 'host1'], ['target', 'host2']])
      end
    end
  end

  describe "sorting query values" do

    context "when query values is a Hash" do
      it "returns an alphabetically sorted hash" do
        sorted_query = WebMock::Util::URI.sort_query_values({"b"=>"one", "a"=>"two"})
        expect(sorted_query).to eq({"a"=>"two", "b"=>"one"})
      end
    end

    context "when query values is an Array" do
      it "returns an alphabetically sorted array" do
        sorted_query = WebMock::Util::URI.sort_query_values([["b","two"],["a","one_b"],["a","one_a"]])
        expect(sorted_query).to eq([["a","one_a"],["a","one_b"],["b","two"]])
      end
    end
  end

  describe "stripping default port" do

    it "should strip_default_port_from_uri strips 80 from http with path" do
      uri = "http://example.com:80/foo/bar"
      stripped_uri = WebMock::Util::URI.strip_default_port_from_uri_string(uri)
      expect(stripped_uri).to eq("http://example.com/foo/bar")
    end

    it "should strip_default_port_from_uri strips 80 from http without path" do
      uri = "http://example.com:80"
      stripped_uri = WebMock::Util::URI.strip_default_port_from_uri_string(uri)
      expect(stripped_uri).to eq("http://example.com")
    end

    it "should strip_default_port_from_uri strips 443 from https without path" do
      uri = "https://example.com:443"
      stripped_uri = WebMock::Util::URI.strip_default_port_from_uri_string(uri)
      expect(stripped_uri).to eq("https://example.com")
    end

    it "should strip_default_port_from_uri strips 443 from https" do
      uri = "https://example.com:443/foo/bar"
      stripped_uri = WebMock::Util::URI.strip_default_port_from_uri_string(uri)
      expect(stripped_uri).to eq("https://example.com/foo/bar")
    end

    it "should strip_default_port_from_uri does not strip 8080 from http" do
      uri = "http://example.com:8080/foo/bar"
      expect(WebMock::Util::URI.strip_default_port_from_uri_string(uri)).to eq(uri)
    end

    it "should strip_default_port_from_uri does not strip 443 from http" do
      uri = "http://example.com:443/foo/bar"
      expect(WebMock::Util::URI.strip_default_port_from_uri_string(uri)).to eq(uri)
    end

    it "should strip_default_port_from_uri does not strip 80 from query string" do
      uri = "http://example.com/?a=:80&b=c"
      expect(WebMock::Util::URI.strip_default_port_from_uri_string(uri)).to eq(uri)
    end

    it "should strip_default_port_from_uri does not modify strings that do not start with http or https" do
      uri = "httpz://example.com:80/"
      expect(WebMock::Util::URI.strip_default_port_from_uri_string(uri)).to eq(uri)
    end

  end


  describe "encoding userinfo" do

    it "should encode unsafe chars in userinfo does not encode userinfo safe punctuation" do
      userinfo = "user;&=+$,:secret"
      expect(WebMock::Util::URI.encode_unsafe_chars_in_userinfo(userinfo)).to eq(userinfo)
    end

    it "should encode unsafe chars in userinfo does not encode rfc 3986 unreserved characters" do
      userinfo = "-.!~*'()abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:secret"
      expect(WebMock::Util::URI.encode_unsafe_chars_in_userinfo(userinfo)).to eq(userinfo)
    end

    it "should encode unsafe chars in userinfo does encode other characters" do
      userinfo, safe_userinfo = 'us#rn@me:sec//ret?"', 'us%23rn%40me:sec%2F%2Fret%3F%22'
      expect(WebMock::Util::URI.encode_unsafe_chars_in_userinfo(userinfo)).to eq(safe_userinfo)
    end

  end

end
