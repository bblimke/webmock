require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')


URIS_WITHOUT_PATH_OR_PARAMS =
[
  "www.google.com",
  "www.google.com/",
  "www.google.com:80",
  "www.google.com:80/",
  "http://www.google.com",
  "http://www.google.com/",
  "http://www.google.com:80",
  "http://www.google.com:80/"
].sort

URIS_WITH_AUTH =
[
  "a b:pass@www.google.com",
  "a b:pass@www.google.com/",
  "a b:pass@www.google.com:80",
  "a b:pass@www.google.com:80/",
  "http://a b:pass@www.google.com",
  "http://a b:pass@www.google.com/",
  "http://a b:pass@www.google.com:80",
  "http://a b:pass@www.google.com:80/",
  "a%20b:pass@www.google.com",
  "a%20b:pass@www.google.com/",
  "a%20b:pass@www.google.com:80",
  "a%20b:pass@www.google.com:80/",
  "http://a%20b:pass@www.google.com",
  "http://a%20b:pass@www.google.com/",
  "http://a%20b:pass@www.google.com:80",
  "http://a%20b:pass@www.google.com:80/"
].sort

URIS_WITH_PATH_AND_PARAMS =
[
  "www.google.com/big image.jpg/?a=big image&b=c",
  "www.google.com/big%20image.jpg/?a=big%20image&b=c",
  "www.google.com:80/big image.jpg/?a=big image&b=c",
  "www.google.com:80/big%20image.jpg/?a=big%20image&b=c",
  "http://www.google.com/big image.jpg/?a=big image&b=c",
  "http://www.google.com/big%20image.jpg/?a=big%20image&b=c",
  "http://www.google.com:80/big image.jpg/?a=big image&b=c",
  "http://www.google.com:80/big%20image.jpg/?a=big%20image&b=c",
  ].sort

URIS_WITH_DIFFERENT_PORT =
[
  "www.google.com:88",
  "www.google.com:88/",
  "http://www.google.com:88",
  "http://www.google.com:88/"
].sort

URIS_FOR_HTTPS =
[
  "https://www.google.com",
  "https://www.google.com/",
  "https://www.google.com:443",
  "https://www.google.com:443/"
].sort


describe WebMock::URI do

  describe "reporting variations of uri" do

    it "should find all variations of the same uri for all variations of uri with params and path" do
      URIS_WITH_PATH_AND_PARAMS.each do |uri|
        WebMock::URI.variations_of_uri_as_strings(uri).sort.should == URIS_WITH_PATH_AND_PARAMS
      end
    end

    it "should find all variations of the same uri for all variations of uri without params or path" do
      URIS_WITHOUT_PATH_OR_PARAMS.each do |uri|
        WebMock::URI.variations_of_uri_as_strings(uri).sort.should == URIS_WITHOUT_PATH_OR_PARAMS
      end
    end

    it "should find all variations of the same uri for all variations of uri with auth" do
      URIS_WITH_AUTH.each do |uri|
        WebMock::URI.variations_of_uri_as_strings(uri).sort.should == URIS_WITH_AUTH
      end
    end

    it "should find all variations of the same uri for all variations of uri with different port" do
      URIS_WITH_DIFFERENT_PORT.each do |uri|
        WebMock::URI.variations_of_uri_as_strings(uri).sort.should == URIS_WITH_DIFFERENT_PORT
      end
    end

    it "should find all variations of the same uri for all variations of https uris" do
      URIS_FOR_HTTPS.each do |uri|
        WebMock::URI.variations_of_uri_as_strings(uri).sort.should == URIS_FOR_HTTPS
      end
    end

  end

  describe "normalized uri equality" do

    it "should successfully compare all variations of the same uri with path and params" do
      URIS_WITH_PATH_AND_PARAMS.each do |uri_a|
        URIS_WITH_PATH_AND_PARAMS.each do |uri_b|
          WebMock::URI.normalize_uri(uri_a).should ===  WebMock::URI.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same uri without path or params" do
      URIS_WITHOUT_PATH_OR_PARAMS.each do |uri_a|
        URIS_WITHOUT_PATH_OR_PARAMS.each do |uri_b|
          WebMock::URI.normalize_uri(uri_a).should ===  WebMock::URI.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same uri with authority" do
      URIS_WITH_AUTH.each do |uri_a|
        URIS_WITH_AUTH.each do |uri_b|
          WebMock::URI.normalize_uri(uri_a).should ===  WebMock::URI.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same uri custom port" do
      URIS_WITH_DIFFERENT_PORT.each do |uri_a|
        URIS_WITH_DIFFERENT_PORT.each do |uri_b|
          WebMock::URI.normalize_uri(uri_a).should ===  WebMock::URI.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same https uri" do
      URIS_FOR_HTTPS.each do |uri_a|
        URIS_FOR_HTTPS.each do |uri_b|
          WebMock::URI.normalize_uri(uri_a).should ===  WebMock::URI.normalize_uri(uri_b)
        end
      end
    end

  end

  describe "stripping default port" do

    it "should strip_default_port_from_uri strips 80 from http with path" do
      uri = "http://example.com:80/foo/bar"
      stripped_uri = WebMock::URI.strip_default_port_from_uri_string(uri)
      stripped_uri.should ==  "http://example.com/foo/bar"
    end

    it "should strip_default_port_from_uri strips 80 from http without path" do
      uri = "http://example.com:80"
      stripped_uri = WebMock::URI.strip_default_port_from_uri_string(uri)
      stripped_uri.should ==  "http://example.com"
    end

    it "should strip_default_port_from_uri strips 443 from https without path" do
      uri = "https://example.com:443"
      stripped_uri = WebMock::URI.strip_default_port_from_uri_string(uri)
      stripped_uri.should ==  "https://example.com"
    end

    it "should strip_default_port_from_uri strips 443 from https" do
      uri = "https://example.com:443/foo/bar"
      stripped_uri = WebMock::URI.strip_default_port_from_uri_string(uri)
      stripped_uri.should == "https://example.com/foo/bar"
    end

    it "should strip_default_port_from_uri does not strip 8080 from http" do
      uri = "http://example.com:8080/foo/bar"
      WebMock::URI.strip_default_port_from_uri_string(uri).should == uri
    end

    it "should strip_default_port_from_uri does not strip 443 from http" do
      uri = "http://example.com:443/foo/bar"
      WebMock::URI.strip_default_port_from_uri_string(uri).should == uri
    end

    it "should strip_default_port_from_uri does not strip 80 from query string" do
      uri = "http://example.com/?a=:80&b=c"
      WebMock::URI.strip_default_port_from_uri_string(uri).should == uri
    end

    it "should strip_default_port_from_uri does not modify strings that do not start with http or https" do
      uri = "httpz://example.com:80/"
      WebMock::URI.strip_default_port_from_uri_string(uri).should == uri
    end

  end


  describe "encoding userinfo" do

    it "should encode unsafe chars in userinfo does not encode userinfo safe punctuation" do
      userinfo = "user;&=+$,:secret"
      WebMock::URI.encode_unsafe_chars_in_userinfo(userinfo).should == userinfo
    end

    it "should encode unsafe chars in userinfo does not encode rfc 3986 unreserved characters" do
      userinfo = "-.!~*'()abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:secret"
      WebMock::URI.encode_unsafe_chars_in_userinfo(userinfo).should == userinfo
    end

    it "should encode unsafe chars in userinfo does encode other characters" do
      userinfo, safe_userinfo = 'us#rn@me:sec//ret?"', 'us%23rn%40me:sec%2F%2Fret%3F%22'
      WebMock::URI.encode_unsafe_chars_in_userinfo(userinfo).should == safe_userinfo
    end

  end

end
