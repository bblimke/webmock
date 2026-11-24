require 'spec_helper'

describe WebMock::Util::Parsers::JSON do
  describe ".parse" do
    it "keeps a date string as a String" do
      expect(described_class.parse("{\"a\":\"2011-01-01\"}")).to eq(
        {"a" => "2011-01-01"}
      )
    end

    it "can parse json with multibyte characters" do
      expect(described_class.parse(
        "{\"name\":\"山田太郎\"\,\"job\":\"会社員\"}"
      )).to eq({"name" => "山田太郎", "job" => "会社員"})
    end

    it "parses a string with an escaped backslash before u0026 (#432)" do
      expect(described_class.parse('{"data":"{\"url\":\"/p?w=1\\\\u0026h=2\"}"}')).to eq(
        {"data" => "{\"url\":\"/p?w=1\\u0026h=2\"}"}
      )
    end

    it "reads numbers with an exponent as numbers" do
      expect(described_class.parse('{"a":1e2,"b":1e+20,"c":1.5e-7}')).to eq(
        {"a" => 100.0, "b" => 1e20, "c" => 1.5e-7}
      )
    end

    it "keeps the last value of a duplicate key, without a warning" do
      expect { expect(described_class.parse('{"a":1,"a":2}')).to eq({"a" => 2}) }.not_to output.to_stderr
    end

    it "parses deeply nested JSON" do
      expect(described_class.parse("[" * 150 + "]" * 150).flatten).to eq([])
    end

    it "parses 1000 levels of nesting and raises ParseError for much more" do
      expect(described_class.parse("[" * 1000 + "]" * 1000).flatten).to eq([])
      expect {
        described_class.parse("[" * 1100 + "]" * 1100)
      }.to raise_error WebMock::Util::Parsers::ParseError
    end

    it "ignores a byte order mark" do
      expect(described_class.parse("\uFEFF{\"a\":1}")).to eq({"a" => 1})
    end

    it "reads a body in another encoding" do
      expect(described_class.parse("{\"a\":\"café\"}".encode(Encoding::ISO_8859_1))).to eq({"a" => "café"})
    end

    it "reads UTF-8 bytes in a binary or US-ASCII string as UTF-8" do
      json = "{\"a\":\"café\"}"
      expect(described_class.parse(json.b)).to eq({"a" => "café"})
      expect(described_class.parse(json.dup.force_encoding(Encoding::US_ASCII))).to eq({"a" => "café"})
    end

    it "raises ParseError for a body that isn't valid UTF-8" do
      expect {
        described_class.parse("{\"a\":\"\xff\"}".b)
      }.to raise_error WebMock::Util::Parsers::ParseError
    end

    it "raises ParseError for a body that isn't valid JSON" do
      ["Bad JSON", "", "{a: 1}", "{'a': 1}", "{\"a\": 1,}", "{\"a\": 2020-01-01}"].each do |json|
        expect {
          described_class.parse(json)
        }.to raise_error(WebMock::Util::Parsers::ParseError), "expected #{json.inspect} to raise ParseError"
      end
    end
  end
end
