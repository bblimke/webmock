if defined?(Patron)

  module Patron
    class Session
            
      def handle_request_with_webmock(req)
        request_signature = build_request_signature(req)

        WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

        if WebMock.registered_request?(request_signature)
          webmock_response = WebMock.response_for_request(request_signature)
          build_patron_response(webmock_response)
        elsif WebMock.net_connect_allowed?
          handle_request_without_webmock(req)
        else
          message = "Real HTTP connections are disabled. Unregistered request: #{request_signature}"
          WebMock.assertion_failure(message)
        end
      end
      
      alias_method :handle_request_without_webmock, :handle_request
      alias_method :handle_request, :handle_request_with_webmock
      
      def build_request_signature(req)
        uri = Addressable::URI.heuristic_parse(req.url)
        uri.path = uri.normalized_path.gsub("[^:]//","/")
        uri.user = req.username       
        uri.password = req.password

        request_signature = WebMock::RequestSignature.new(
          req.action,
          uri.to_s,
          :body => req.upload_data,
          :headers => req.headers
        )
        request_signature
      end
      
      def build_patron_response(webmock_response)
        webmock_response.raise_error_if_any
        res = Patron::Response.new
        res.instance_variable_set(:@body, webmock_response.body)
        res.instance_variable_set(:@status, webmock_response.status)
        res.instance_variable_set(:@headers, webmock_response.headers)
        res
      end
      
    end
  end

end
