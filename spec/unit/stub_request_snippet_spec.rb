require 'spec_helper'

describe WebMock::StubRequestSnippet do
  describe "to_s" do
    describe "GET" do
      before(:each) do
        @request_signature = WebMock::RequestSignature.new(:get, "www.example.com/?a=b&c=d", headers: {})
      end

      it "should print stub request snippet with url with params and method and empty successful response" do
        expected = %Q(stub_request(:get, "http://www.example.com/?a=b&c=d").\n  to_return(status: 200, body: "", headers: {}))
        @request_stub = WebMock::RequestStub.from_request_signature(@request_signature)
        expect(WebMock::StubRequestSnippet.new(@request_stub).to_s).to eq(expected)
      end

      it "should print stub request snippet with body if available" do
        @request_signature.body = "abcdef"
        expected = %Q(stub_request(:get, "http://www.example.com/?a=b&c=d").)+
        "\n  with(\n    body: \"abcdef\")." +
        "\n  to_return(status: 200, body: \"\", headers: {})"
        @request_stub = WebMock::RequestStub.from_request_signature(@request_signature)
        expect(WebMock::StubRequestSnippet.new(@request_stub).to_s).to eq(expected)
      end

      it "should print stub request snippet with multiline body" do
        @request_signature.body = "abc\ndef"
        expected = %Q(stub_request(:get, "http://www.example.com/?a=b&c=d").)+
        "\n  with(\n    body: \"abc\\ndef\")." +
        "\n  to_return(status: 200, body: \"\", headers: {})"
        @request_stub = WebMock::RequestStub.from_request_signature(@request_signature)
        expect(WebMock::StubRequestSnippet.new(@request_stub).to_s).to eq(expected)
      end

      it "should print stub request snippet with headers if any" do
        @request_signature.headers = {'B' => 'b', 'A' => 'a'}
        expected = 'stub_request(:get, "http://www.example.com/?a=b&c=d").'+
        "\n  with(\n    headers: {\n\t\  'A\'=>\'a\',\n\t  \'B\'=>\'b\'\n    })." +
        "\n  to_return(status: 200, body: \"\", headers: {})"
        @request_stub = WebMock::RequestStub.from_request_signature(@request_signature)
        expect(WebMock::StubRequestSnippet.new(@request_stub).to_s).to eq(expected)
      end

      it "should print stub request snippet with body and headers" do
        @request_signature.body = "abcdef"
        @request_signature.headers = {'B' => 'b', 'A' => 'a'}
        expected = 'stub_request(:get, "http://www.example.com/?a=b&c=d").'+
        "\n  with(\n    body: \"abcdef\",\n    headers: {\n\t  \'A\'=>\'a\',\n\t  \'B\'=>\'b\'\n    })." +
        "\n  to_return(status: 200, body: \"\", headers: {})"
        @request_stub = WebMock::RequestStub.from_request_signature(@request_signature)
        expect(WebMock::StubRequestSnippet.new(@request_stub).to_s).to eq(expected)
      end

      it "should not print to_return part if not wanted" do
        expected = 'stub_request(:get, "http://www.example.com/").'+
        "\n  with(\n    body: \"abcdef\")"
        stub = WebMock::RequestStub.new(:get, "www.example.com").with(body: "abcdef").to_return(body: "hello")
        expect(WebMock::StubRequestSnippet.new(stub).to_s(false)).to eq(expected)
      end
    end

    describe "POST" do
      let(:form_body) { 'user%5bfirst_name%5d=Bartosz' }
      let(:multipart_form_body) { 'complicated stuff--ABC123--goes here' }
      it "should print stub request snippet with body as a hash using rails conventions on form posts" do
        @request_signature = WebMock::RequestSignature.new(:post, "www.example.com",
                   headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
                   body: form_body)
        @request_stub = WebMock::RequestStub.from_request_signature(@request_signature)
        expected = <<-STUB
stub_request(:post, "http://www.example.com/").
  with(
    body: #{{"user" => {"first_name" => "Bartosz"}}},
    headers: {
\t  'Content-Type'=>'application/x-www-form-urlencoded'
    }).
  to_return(status: 200, body: \"\", headers: {})
        STUB
        expect(WebMock::StubRequestSnippet.new(@request_stub).to_s).to eq(expected.strip)
      end

      it "should print stub request snippet leaving body as string when not a urlencoded form" do
        @request_signature = WebMock::RequestSignature.new(:post, "www.example.com",
                   headers: {'Content-Type' => 'multipart/form-data; boundary=ABC123'},
                   body: multipart_form_body)
        @request_stub = WebMock::RequestStub.from_request_signature(@request_signature)
        expected = <<-STUB
stub_request(:post, "http://www.example.com/").
  with(
    body: "#{multipart_form_body}",
    headers: {
\t  'Content-Type'=>'multipart/form-data; boundary=ABC123'
    }).
  to_return(status: 200, body: \"\", headers: {})
        STUB
        expect(WebMock::StubRequestSnippet.new(@request_stub).to_s).to eq(expected.strip)
      end

      it "should print stub request snippet with valid JSON body when request header contains 'Accept'=>'application/json' " do
        @request_signature = WebMock::RequestSignature.new(:post, "www.example.com",
                   headers: {'Accept' => 'application/json'})
        @request_stub = WebMock::RequestStub.from_request_signature(@request_signature)
        expected = <<-STUB
stub_request(:post, "http://www.example.com/").
  with(
    headers: {
\t  'Accept'=>'application/json'
    }).
  to_return(status: 200, body: \"{}\", headers: {})
        STUB
        expect(WebMock::StubRequestSnippet.new(@request_stub).to_s).to eq(expected.strip)
      end
    end

  end

  describe "to_s for a registered stub" do
    def snippet(stub)
      WebMock::StubRequestSnippet.new(stub).to_s(false)
    end

    it "writes a URI template as Ruby" do
      stub = WebMock::RequestStub.new(:get, Addressable::Template.new("http://localhost:9200/{index}/_search"))
      expect(snippet(stub)).to eq('stub_request(:get, Addressable::Template.new("http://localhost:9200/{index}/_search"))')
    end

    it "writes a regexp as Ruby" do
      expect(snippet(WebMock::RequestStub.new(:get, /example\.org/))).to eq('stub_request(:get, /example\.org/)')
    end

    it "keeps a lambda in quotes, as before" do
      expect(snippet(WebMock::RequestStub.new(:get, ->(_uri) { true }))).to start_with('stub_request(:get, "#<Proc:')
    end

    it "writes a query given to a template as the query option" do
      stub = WebMock::RequestStub.new(:get, Addressable::Template.new("http://localhost:9200/{index}/_count")).
        with(query: {"a" => "b"})
      expect(snippet(stub)).to eq(
        %(stub_request(:get, Addressable::Template.new("http://localhost:9200/{index}/_count")).\n  with(\n    query: #{{"a" => "b"}.inspect}))
      )
    end

    it "writes a query matcher of a string URI as the query option" do
      stub = WebMock::RequestStub.new(:get, "www.example.com").with(query: hash_including("a" => "1"))
      expect(snippet(stub)).to eq(
        %(stub_request(:get, "http://www.example.com/").\n  with(\n    query: hash_including(#{{"a" => "1"}.inspect})))
      )
    end

    it "writes any query as :any" do
      stub = WebMock::RequestStub.new(:get, /example/).with(query: :any)
      expect(snippet(stub)).to eq(%(stub_request(:get, /example/).\n  with(\n    query: :any)))
    end

    it "writes a :flat_array query as a string" do
      WebMock::Config.instance.query_values_notation = :flat_array
      stub = WebMock::RequestStub.new(:get, /example/).with(query: "a=2&a=1")
      expect(snippet(stub)).to eq(%(stub_request(:get, /example/).\n  with(\n    query: "a=1&a=2")))
    ensure
      WebMock::Config.instance.query_values_notation = nil
    end

    it "writes the query before the body" do
      stub = WebMock::RequestStub.new(:post, /example/).with(query: {"a" => "b"}, body: "x")
      expect(snippet(stub)).to eq(
        %(stub_request(:post, /example/).\n  with(\n    query: #{{"a" => "b"}.inspect},\n    body: "x"))
      )
    end
  end
end
