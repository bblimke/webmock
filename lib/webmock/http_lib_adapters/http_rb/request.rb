# frozen_string_literal: true

module HTTP
  class Request
    def webmock_signature
      request_body = if defined?(HTTP::Request::Body)
                       String.new.tap { |string| body.each { |part| string << part } }
                     else
                       body
                     end

      ::WebMock::RequestSignature.new(verb, uri.to_s, {
        headers: headers.to_h,
        body: request_body
      })
    end
  end
end
