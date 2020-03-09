module HTTP
  class Response
    def to_webmock
      webmock_response = ::WebMock::Response.new

      webmock_response.status  = [status.to_i, reason]
      webmock_response.body    = body.to_s
      webmock_response.headers = headers.to_h

      webmock_response
    end

    class << self
      def from_webmock(webmock_response, request_signature = nil)
        status  = Status.new(webmock_response.status.first)
        headers = webmock_response.headers || {}
        uri     = normalize_uri(request_signature && request_signature.uri)

        # HTTP.rb 3.0+ uses a keyword argument to pass the encoding, but 1.x
        # and 2.x use a positional argument, and 0.x don't support supplying
        # the encoding.
        body = if HTTP::VERSION < "1.0.0"
          Body.new(Streamer.new(webmock_response.body))
        elsif HTTP::VERSION < "3.0.0"
          Body.new(Streamer.new(webmock_response.body), webmock_response.body.encoding)
        else
          Body.new(Streamer.new(webmock_response.body), encoding: webmock_response.body.encoding)
        end

        return new(status, "1.1", headers, body, uri) if HTTP::VERSION < "1.0.0"

        new({
          status: status,
          version: "1.1",
          headers: headers,
          body: body,
          uri: uri
        })
      end

      private

      def normalize_uri(uri)
        return unless uri

        uri = Addressable::URI.parse uri
        uri.port = nil if uri.default_port && uri.port == uri.default_port

        uri
      end
    end
  end
end
