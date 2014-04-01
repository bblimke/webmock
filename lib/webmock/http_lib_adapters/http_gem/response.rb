module HTTP
  class Response
    def to_webmock
      webmock_response = ::WebMock::Response.new

      webmock_response.status  = [status, reason]
      webmock_response.body    = body.to_s
      webmock_response.headers = headers.to_h

      webmock_response
    end

    def self.from_webmock(webmock_response)
      status  = webmock_response.status.first
      headers = webmock_response.headers || {}
      body    = Body.new Streamer.new webmock_response.body

      new(status, "1.1", headers, body)
    end
  end
end
