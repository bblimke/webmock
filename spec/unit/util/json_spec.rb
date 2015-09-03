# encoding: utf-8
require 'spec_helper'

describe WebMock::Util::JSON do
  describe ".parse" do
    it "should parse json without parsing dates" do
      expect(WebMock::Util::JSON.parse("\"a\":\"2011-01-01\"")).to eq(
        {"a" => "2011-01-01"}
      )
    end

    it "can parse json with multibyte characters" do
      expect(WebMock::Util::JSON.parse(
        "{\"name\":\"山田太郎\"\,\"job\":\"会社員\"}"
      )).to eq({"name" => "山田太郎", "job" => "会社員"})
    end

    it "rescues ArgumentError's from YAML.load" do
      allow(YAML).to receive(:load).and_raise(ArgumentError)
      expect {
        WebMock::Util::JSON.parse("Bad JSON")
      }.to raise_error WebMock::Util::JSON::ParseError
    end
  end

  describe ".convert_json_to_yaml" do
    it "parses multibyte characters" do
      expect(WebMock::Util::JSON.convert_json_to_yaml(
        "{\"name\":\"山田太郎\"\,\"job\":\"会社員\"}"
      )).to eq "{\"name\": \"山田太郎\", \"job\": \"会社員\"}"
    end
  end
end
