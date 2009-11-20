require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Utility do

  it "should decode_userinfo_from_header handles basic auth" do
    authorization_header = "Basic dXNlcm5hbWU6c2VjcmV0"
    userinfo = Utility.decode_userinfo_from_header(authorization_header)
    userinfo.should == "username:secret"
  end

  it "should encode unsafe chars in userinfo does not encode userinfo safe punctuation" do
    userinfo = "user;&=+$,:secret"
    userinfo.should == Utility.encode_unsafe_chars_in_userinfo(userinfo)
  end

  it "should encode unsafe chars in userinfo does not encode rfc 3986 unreserved characters" do
    userinfo = "-.!~*'()abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:secret"
    userinfo.should == Utility.encode_unsafe_chars_in_userinfo(userinfo)
  end

  it "should encode unsafe chars in userinfo does encode other characters" do
    userinfo, safe_userinfo = 'us#rn@me:sec//ret?"', 'us%23rn%40me:sec%2F%2Fret%3F%22'
    safe_userinfo.should == Utility.encode_unsafe_chars_in_userinfo(userinfo)
  end

  it "should strip_default_port_from_uri strips 80 from http with path" do
    uri = "http://example.com:80/foo/bar"
    stripped_uri = Utility.strip_default_port_from_uri(uri)
    stripped_uri.should ==  "http://example.com/foo/bar"
  end

  it "should strip_default_port_from_uri strips 80 from http without path" do
    uri = "http://example.com:80"
    stripped_uri = Utility.strip_default_port_from_uri(uri)
    stripped_uri.should ==  "http://example.com"
  end

  it "should strip_default_port_from_uri strips 443 from https without path" do
    uri = "https://example.com:443"
    stripped_uri = Utility.strip_default_port_from_uri(uri)
    stripped_uri.should ==  "https://example.com"
  end

  it "should strip_default_port_from_uri strips 443 from https" do
    uri = "https://example.com:443/foo/bar"
    stripped_uri = Utility.strip_default_port_from_uri(uri)
    stripped_uri.should == "https://example.com/foo/bar"
  end

  it "should strip_default_port_from_uri does not strip 8080 from http" do
    uri = "http://example.com:8080/foo/bar"
    uri.should == Utility.strip_default_port_from_uri(uri)
  end

  it "should strip_default_port_from_uri does not strip 443 from http" do
    uri = "http://example.com:443/foo/bar"
    uri.should == Utility.strip_default_port_from_uri(uri)
  end

  it "should strip_default_port_from_uri does not strip 80 from query string" do
    uri = "http://example.com/?a=:80&b=c"
    uri.should == Utility.strip_default_port_from_uri(uri)
  end

  it "should strip_default_port_from_uri does not modify strings that do not start with http or https" do
    uri = "httpz://example.com:80/"
    uri.should == Utility.strip_default_port_from_uri(uri)
  end

end
