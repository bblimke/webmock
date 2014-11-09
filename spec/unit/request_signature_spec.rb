require 'spec_helper'

describe WebMock::RequestSignature do

  describe "initialization" do

    it "should have assigned normalized uri" do
      expect(WebMock::Util::URI).to receive(:normalize_uri).and_return("www.example.kom")
      signature = WebMock::RequestSignature.new(:get, "www.example.com")
      expect(signature.uri).to eq("www.example.kom")
    end

    it "should have assigned uri without normalization if uri is URI" do
      expect(WebMock::Util::URI).not_to receive(:normalize_uri)
      uri = Addressable::URI.parse("www.example.com")
      signature = WebMock::RequestSignature.new(:get, uri)
      expect(signature.uri).to eq(uri)
    end

    it "should have assigned normalized headers" do
      expect(WebMock::Util::Headers).to receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
      expect(WebMock::RequestSignature.new(:get, "www.example.com", :headers => {'A' => 'a'}).headers).to eq({'B' => 'b'})
    end

    it "should have assigned body" do
      expect(WebMock::RequestSignature.new(:get, "www.example.com", :body => "abc").body).to eq("abc")
    end

    it "should symbolize the method" do
      expect(WebMock::RequestSignature.new('get', "www.example.com", :body => "abc").method).to eq(:get)
    end
  end

  it "should report string describing itself" do
    expect(WebMock::RequestSignature.new(:get, "www.example.com",
      :body => "abc", :headers => {'A' => 'a', 'B' => 'b'}).to_s).to eq(
    "GET http://www.example.com/ with body 'abc' with headers {'A'=>'a', 'B'=>'b'}"
    )
  end

  describe "hash" do
    it "should report same hash for two signatures with the same values" do
      signature1 = WebMock::RequestSignature.new(:get, "www.example.com",
        :body => "abc", :headers => {'A' => 'a', 'B' => 'b'})
      signature2 = WebMock::RequestSignature.new(:get, "www.example.com",
        :body => "abc", :headers => {'A' => 'a', 'B' => 'b'})
      expect(signature1.hash).to eq(signature2.hash)
    end

    it "should report different hash for two signatures with different method" do
      signature1 = WebMock::RequestSignature.new(:get, "www.example.com")
      signature2 = WebMock::RequestSignature.new(:put, "www.example.com")
      expect(signature1.hash).not_to eq(signature2.hash)
    end

    it "should report different hash for two signatures with different uri" do
      signature1 = WebMock::RequestSignature.new(:get, "www.example.com")
      signature2 = WebMock::RequestSignature.new(:get, "www.example.org")
      expect(signature1.hash).not_to eq(signature2.hash)
    end

    it "should report different hash for two signatures with different body" do
      signature1 = WebMock::RequestSignature.new(:get, "www.example.com", :body => "abc")
      signature2 = WebMock::RequestSignature.new(:get, "www.example.com", :body => "def")
      expect(signature1.hash).not_to eq(signature2.hash)
    end

    it "should report different hash for two signatures with different headers" do
      signature1 = WebMock::RequestSignature.new(:get, "www.example.com",
        :headers => {'A' => 'a'})
      signature2 = WebMock::RequestSignature.new(:get, "www.example.com",
        :headers => {'A' => 'A'})
      expect(signature1.hash).not_to eq(signature2.hash)
    end
  end


  [:==, :eql?].each do |method|
    describe method do
      it "should be true for two signatures with the same values" do
        signature1 = WebMock::RequestSignature.new(:get, "www.example.com",
          :body => "abc", :headers => {'A' => 'a', 'B' => 'b'})
        signature2 = WebMock::RequestSignature.new(:get, "www.example.com",
          :body => "abc", :headers => {'A' => 'a', 'B' => 'b'})

        expect(signature1.send(method, signature2)).to be_truthy
      end

      it "should be false for two signatures with different method" do
        signature1 = WebMock::RequestSignature.new(:get, "www.example.com")
        signature2 = WebMock::RequestSignature.new(:put, "www.example.com")
        expect(signature1.send(method, signature2)).to be_falsey
      end

      it "should be false for two signatures with different uri" do
        signature1 = WebMock::RequestSignature.new(:get, "www.example.com")
        signature2 = WebMock::RequestSignature.new(:get, "www.example.org")
        expect(signature1.send(method, signature2)).to be_falsey
      end

      it "should be false for two signatures with different body" do
        signature1 = WebMock::RequestSignature.new(:get, "www.example.com", :body => "abc")
        signature2 = WebMock::RequestSignature.new(:get, "www.example.com", :body => "def")
        expect(signature1.send(method, signature2)).to be_falsey
      end

      it "should be false for two signatures with different headers" do
        signature1 = WebMock::RequestSignature.new(:get, "www.example.com",
          :headers => {'A' => 'a'})
        signature2 = WebMock::RequestSignature.new(:get, "www.example.com",
          :headers => {'A' => 'A'})
        expect(signature1.send(method, signature2)).to be_falsey
      end
    end
  end

end
