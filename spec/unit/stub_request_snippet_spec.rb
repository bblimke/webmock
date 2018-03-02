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
    body: {"user"=>{"first_name"=>"Bartosz"}},
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
end
