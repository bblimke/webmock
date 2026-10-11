require 'spec_helper'

describe WebMock::Util::ContentType do
  describe ".media_type" do
    it "removes parameters and surrounding spaces and ignores case" do
      expect(WebMock::Util::ContentType.media_type("Application/JSON ; charset=UTF-8")).to eq("application/json")
    end

    it "returns an empty string when there is no content type" do
      expect(WebMock::Util::ContentType.media_type(nil)).to eq("")
    end

    it "does not raise on invalid UTF-8 bytes" do
      content_type = "application/json; charset=\xFF".dup.force_encoding(Encoding::UTF_8)
      expect(WebMock::Util::ContentType.media_type(content_type)).to eq("application/json")
    end
  end

  describe ".url_encoded?" do
    {
      "application/x-www-form-urlencoded"                => true,
      "application/x-www-form-urlencoded; charset=UTF-8" => true,
      "Application/X-WWW-Form-Urlencoded"                => true,
      "application/x-www-form-urlencoded-other"          => false,
      "application/json"                                 => false,
      nil                                                => false
    }.each do |content_type, url_encoded|
      it "returns #{url_encoded} for #{content_type.inspect}" do
        expect(WebMock::Util::ContentType.url_encoded?(content_type)).to be(url_encoded)
      end
    end
  end

  describe ".body_format" do
    {
      "application/json"                  => :json,
      "application/json; charset=utf-8"   => :json,
      "Application/JSON ; charset=UTF-8"  => :json,
      "text/json"                         => :json,
      "application/vnd.api+json"          => :json,
      "application/problem+json"          => :json,
      "application/vnd.github.v3+json"    => :json,
      "application/vnd.foo_bar+json"      => :json,
      "application/atom+xml"              => :xml,
      "image/svg+xml"                     => :xml,
      "application/xml; charset=utf-8"    => :xml,
      "application/json-seq"              => nil,
      "application/x-ndjson"              => nil,
      "application/x-www-form-urlencoded" => nil,
      ""                                  => nil,
      nil                                 => nil
    }.each do |content_type, format|
      it "returns #{format.inspect} for #{content_type.inspect}" do
        expect(WebMock::Util::ContentType.body_format(content_type)).to eq(format)
      end
    end
  end
end
