require 'spec_helper'

describe WebMock::RequestSignature do

  describe "initialization" do

    it "assign the uri to be the normalized uri" do
      expect(WebMock::Util::URI).to receive(:normalize_uri).and_return("www.example.kom")
      signature = WebMock::RequestSignature.new(:get, "www.example.com")
      expect(signature.uri).to eq("www.example.kom")
    end

    it "assigns the uri without normalization if uri is already a URI" do
      expect(WebMock::Util::URI).not_to receive(:normalize_uri)
      uri = Addressable::URI.parse("www.example.com")
      signature = WebMock::RequestSignature.new(:get, uri)
      expect(signature.uri).to eq(uri)
    end

    it "assigns normalized headers" do
      expect(WebMock::Util::Headers).to receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
      expect(
        WebMock::RequestSignature.new(:get, "www.example.com", headers: {'A' => 'a'}).headers
      ).to eq({'B' => 'b'})
    end

    it "assign the body" do
      expect(WebMock::RequestSignature.new(:get, "www.example.com", body: "abc").body).to eq("abc")
    end

    it "symbolizes the method" do
      expect(WebMock::RequestSignature.new('get', "www.example.com", body: "abc").method).to eq(:get)
    end
  end

  describe "#to_s" do
    it "describes itself" do
      expect(WebMock::RequestSignature.new(:get, "www.example.com",
        body: "abc", headers: {'A' => 'a', 'B' => 'b'}).to_s).to eq(
      "GET http://www.example.com/ with body 'abc' with headers {'A'=>'a', 'B'=>'b'}"
      )
    end
  end

  describe "#hash" do
    it "reporst same hash for two signatures with the same values" do
      signature1 = WebMock::RequestSignature.new(:get, "www.example.com",
        body: "abc", headers: {'A' => 'a', 'B' => 'b'})
      signature2 = WebMock::RequestSignature.new(:get, "www.example.com",
        body: "abc", headers: {'A' => 'a', 'B' => 'b'})
      expect(signature1.hash).to eq(signature2.hash)
    end

    it "reports different hash for two signatures with different method" do
      signature1 = WebMock::RequestSignature.new(:get, "www.example.com")
      signature2 = WebMock::RequestSignature.new(:put, "www.example.com")
      expect(signature1.hash).not_to eq(signature2.hash)
    end

    it "reports different hash for two signatures with different uri" do
      signature1 = WebMock::RequestSignature.new(:get, "www.example.com")
      signature2 = WebMock::RequestSignature.new(:get, "www.example.org")
      expect(signature1.hash).not_to eq(signature2.hash)
    end

    it "reports different hash for two signatures with different body" do
      signature1 = WebMock::RequestSignature.new(:get, "www.example.com", body: "abc")
      signature2 = WebMock::RequestSignature.new(:get, "www.example.com", body: "def")
      expect(signature1.hash).not_to eq(signature2.hash)
    end

    it "reports different hash for two signatures with different headers" do
      signature1 = WebMock::RequestSignature.new(:get, "www.example.com",
        headers: {'A' => 'a'})
      signature2 = WebMock::RequestSignature.new(:get, "www.example.com",
        headers: {'A' => 'A'})
      expect(signature1.hash).not_to eq(signature2.hash)
    end
  end

  [:==, :eql?].each do |method|
    describe method do
      it "is true for two signatures with the same values" do
        signature1 = WebMock::RequestSignature.new(:get, "www.example.com",
          body: "abc", headers: {'A' => 'a', 'B' => 'b'})
        signature2 = WebMock::RequestSignature.new(:get, "www.example.com",
          body: "abc", headers: {'A' => 'a', 'B' => 'b'})

        expect(signature1.send(method, signature2)).to be_truthy
      end

      it "is false for two signatures with different method" do
        signature1 = WebMock::RequestSignature.new(:get, "www.example.com")
        signature2 = WebMock::RequestSignature.new(:put, "www.example.com")
        expect(signature1.send(method, signature2)).to be_falsey
      end

      it "is false for two signatures with different uri" do
        signature1 = WebMock::RequestSignature.new(:get, "www.example.com")
        signature2 = WebMock::RequestSignature.new(:get, "www.example.org")
        expect(signature1.send(method, signature2)).to be_falsey
      end

      it "is false for two signatures with different body" do
        signature1 = WebMock::RequestSignature.new(:get, "www.example.com", body: "abc")
        signature2 = WebMock::RequestSignature.new(:get, "www.example.com", body: "def")
        expect(signature1.send(method, signature2)).to be_falsey
      end

      it "is false for two signatures with different headers" do
        signature1 = WebMock::RequestSignature.new(:get, "www.example.com",
          headers: {'A' => 'a'})
        signature2 = WebMock::RequestSignature.new(:get, "www.example.com",
          headers: {'A' => 'A'})
        expect(signature1.send(method, signature2)).to be_falsey
      end
    end
  end

  subject { WebMock::RequestSignature.new(:get, "www.example.com") }

  describe "#url_encoded?" do
    it "returns true if the headers are urlencoded" do
      subject.headers = { "Content-Type" => "application/x-www-form-urlencoded" }
      expect(subject.url_encoded?).to be true
    end

    it "returns false if the headers are NOT urlencoded" do
      subject.headers = { "Content-Type" => "application/made-up-format" }
      expect(subject.url_encoded?).to be false
    end

    it "returns false when no headers are set" do
      subject.headers = nil
      expect(subject.url_encoded?).to be false
    end
  end

  describe "#json_headers?" do
    it "returns true if the headers are json" do
      subject.headers = { "Content-Type" => "application/json" }
      expect(subject.json_headers?).to be true
    end

    it "returns false if the headers are NOT json" do
      subject.headers = { "Content-Type" => "application/made-up-format" }
      expect(subject.json_headers?).to be false
    end

    it "returns false when no headers are set" do
      subject.headers = nil
      expect(subject.json_headers?).to be false
    end
  end
end
