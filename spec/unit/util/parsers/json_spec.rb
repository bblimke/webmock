require 'spec_helper'

describe WebMock::Util::Parsers::JSON do
  describe ".parse" do
    it "should parse json without parsing dates" do
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

  describe ".parse_legacy" do
    it "should parse json without parsing dates" do
      expect(described_class.parse_legacy("\"a\":\"2011-01-01\"")).to eq(
        {"a" => "2011-01-01"}
      )
    end

    it "can parse json with multibyte characters" do
      expect(described_class.parse_legacy(
        "{\"name\":\"山田太郎\"\,\"job\":\"会社員\"}"
      )).to eq({"name" => "山田太郎", "job" => "会社員"})
    end

    it "reads some bodies that aren't valid JSON" do
      ["{a: 1}", "{'a': 1}", "{\"a\": 1,}"].each do |json|
        expect(described_class.parse_legacy(json)).to eq({"a" => 1})
      end
    end

    it "rescues ArgumentError's from YAML.load" do
      allow(YAML).to receive(:load).and_raise(ArgumentError)
      expect {
        described_class.parse_legacy("Bad JSON")
      }.to raise_error WebMock::Util::Parsers::ParseError
    end

    it "rescues Psych::SyntaxError's from YAML.load" do
      allow(YAML).to receive(:load).and_raise(Psych::SyntaxError)
      expect {
        described_class.parse_legacy("Bad JSON")
      }.to raise_error WebMock::Util::Parsers::ParseError
    end

    it "rescues Psych::DisallowedClass from YAML.load" do
      # Psych 4 and later take the action and the class name, Psych 3 only the class name.
      arguments = Psych::DisallowedClass.instance_method(:initialize).arity == 1 ? ["Date"] : ["load", "Date"]
      allow(YAML).to receive(:load).and_raise(Psych::DisallowedClass.new(*arguments))
      expect {
        described_class.parse_legacy("{\"a\": 2020-01-01}")
      }.to raise_error WebMock::Util::Parsers::ParseError
    end
  end

  describe ".convert_json_to_yaml" do
    it "parses multibyte characters" do
      expect(described_class.convert_json_to_yaml(
        "{\"name\":\"山田太郎\"\,\"job\":\"会社員\"}"
      )).to eq "{\"name\": \"山田太郎\", \"job\": \"会社員\"}"
    end
  end
end
