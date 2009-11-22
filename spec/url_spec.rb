require File.expand_path(File.dirname(__FILE__) + '/spec_helper')


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


describe URL do

  describe "reporting variations of uri" do

    it "should find all variations of the same uri for all variations of uri with params and path" do
      URIS_WITH_PATH_AND_PARAMS.each do |uri|
        URL.variations_of_uri_as_strings(uri).sort.should == URIS_WITH_PATH_AND_PARAMS
      end
    end

    it "should find all variations of the same uri for all variations of uri without params or path" do
      URIS_WITHOUT_PATH_OR_PARAMS.each do |uri|
        URL.variations_of_uri_as_strings(uri).sort.should == URIS_WITHOUT_PATH_OR_PARAMS
      end
    end

    it "should find all variations of the same uri for all variations of uri with auth" do
      URIS_WITH_AUTH.each do |uri|
        URL.variations_of_uri_as_strings(uri).sort.should == URIS_WITH_AUTH
      end
    end

    it "should find all variations of the same uri for all variations of uri with different port" do
      URIS_WITH_DIFFERENT_PORT.each do |uri|
        URL.variations_of_uri_as_strings(uri).sort.should == URIS_WITH_DIFFERENT_PORT
      end
    end

    it "should find all variations of the same uri for all variations of https uris" do
      URIS_FOR_HTTPS.each do |uri|
        URL.variations_of_uri_as_strings(uri).sort.should == URIS_FOR_HTTPS
      end
    end

  end

  describe "normalized url equality" do

    it "should successfully compare all variations of the same uri with path and params" do
      URIS_WITH_PATH_AND_PARAMS.each do |uri_a|
        URIS_WITH_PATH_AND_PARAMS.each do |uri_b|
          URL.normalize_uri(uri_a).should ===  URL.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same uri without path or params" do
      URIS_WITHOUT_PATH_OR_PARAMS.each do |uri_a|
        URIS_WITHOUT_PATH_OR_PARAMS.each do |uri_b|
          URL.normalize_uri(uri_a).should ===  URL.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same uri with authority" do
      URIS_WITH_AUTH.each do |uri_a|
        URIS_WITH_AUTH.each do |uri_b|
          URL.normalize_uri(uri_a).should ===  URL.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same uri custom port" do
      URIS_WITH_DIFFERENT_PORT.each do |uri_a|
        URIS_WITH_DIFFERENT_PORT.each do |uri_b|
          URL.normalize_uri(uri_a).should ===  URL.normalize_uri(uri_b)
        end
      end
    end

    it "should successfully compare all variations of the same https uri" do
      URIS_FOR_HTTPS.each do |uri_a|
        URIS_FOR_HTTPS.each do |uri_b|
          URL.normalize_uri(uri_a).should ===  URL.normalize_uri(uri_b)
        end
      end
    end


  end

end
