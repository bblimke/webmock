require 'spec_helper'

describe WebMock::Util::Headers do

  it "should decode_userinfo_from_header handles basic auth" do
    authorization_header = "Basic dXNlcm5hbWU6c2VjcmV0"
    userinfo = WebMock::Util::Headers.decode_userinfo_from_header(authorization_header)
    expect(userinfo).to eq("username:secret")
  end

  describe "sorted_headers_string" do

    it "should return nice string for hash with string values" do
      expect(WebMock::Util::Headers.sorted_headers_string({"a" => "b"})).to eq("{'A'=>'b'}")
    end

    it "should return nice string for hash with array values" do
      expect(WebMock::Util::Headers.sorted_headers_string({"a" => ["b", "c"]})).to eq("{'A'=>['b', 'c']}")
    end

    it "should return nice string for hash with array values and string values" do
      expect(WebMock::Util::Headers.sorted_headers_string({"a" => ["b", "c"], "d" => "e"})).to eq("{'A'=>['b', 'c'], 'D'=>'e'}")
    end


  end

  describe ".normalize_headers" do
    it "normalizes capitalization for string header names" do
      expect(described_class.normalize_headers({ "foo-BAR-bAz" => "qUx" }))
        .to eq({ "Foo-Bar-Baz" => "qUx" })
    end

    it "stringifies and dasherizes symbol header names" do
      expect(described_class.normalize_headers({ foo_bar: "qUx" }))
        .to eq({ "Foo-Bar" => "qUx" })
    end

    it "respects choice of underscores for string header names" do
      expect(described_class.normalize_headers({ "foo-BAR_bAz" => "qUx" }))
        .to eq({ "Foo-Bar_Baz" => "qUx" })
    end
  end
end
