module WebMock
  class StubRequestSnippet
    def initialize(request_signature)
      @request_signature = request_signature
    end

    def to_s
      string = "stub_request(:#{@request_signature.method},"
      string << " \"#{WebMock::Util::URI.strip_default_port_from_uri_string(@request_signature.uri.to_s)}\")"

      with = ""

      if (@request_signature.body.to_s != '')
        body = use_body_hash? ? body_hash : @request_signature.body
        with << ":body => #{body.inspect}"
      end

      if (@request_signature.headers && !@request_signature.headers.empty?)
        with << ",\n       " unless with.empty?

        with << ":headers => #{WebMock::Util::Headers.sorted_headers_string(@request_signature.headers)}"
      end
      string << ".\n  with(#{with})" unless with.empty?
      string << ".\n  to_return(:status => 200, :body => \"\", :headers => {})"
      string
    end

    def body_hash
      Addressable::URI.parse('?' + @request_signature.body).query_values
    end

    def use_body_hash?
      @request_signature.headers['Content-Type'] == 'application/x-www-form-urlencoded'
    end

  end
end
