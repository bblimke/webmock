module HTTP
  class Response
    def to_webmock
      webmock_response = ::WebMock::Response.new

      webmock_response.status  = [status.to_i, reason]
      webmock_response.body    = body.to_s
      webmock_response.headers = headers.to_h

      webmock_response
    end

    def self.from_webmock(webmock_response, request_signature = nil)
      status  = Status.new(webmock_response.status.first)
      headers = webmock_response.headers || {}
      body    = Body.new Streamer.new webmock_response.body
      uri     = URI request_signature.uri.to_s if request_signature

      new(status, "1.1", headers, body, uri)
    end
  end
end
