module HTTP
  class Request
    def webmock_signature
      ::WebMock::RequestSignature.new(verb, uri.to_s, {
        :headers  => headers.to_h,
        :body     => body
      })
    end
  end
end
