if defined?(Typhoeus)
  module Typhoeus
    class Easy
      def build_request_signature
        uri = WebMock::Util::URI.heuristic_parse(self.url)
        uri.path = uri.normalized_path.gsub("[^:]//","/")
        if @webmock_auth
          uri.user = @webmock_auth[:username]
          uri.password = @webmock_auth[:password]
        end

        request_signature = WebMock::RequestSignature.new(
          @method,
          uri.to_s,
          :body => @request_body,
          :headers => @headers
        )
        request_signature
      end
      
      def build_webmock_response
        response = Typhoeus::Response.new(:headers => self.response_header)
        webmock_response = WebMock::Response.new
        webmock_response.status = [self.response_code, response.status_message]
        webmock_response.body = self.response_body
        webmock_response.headers = WebMock::Util::Headers.normalize_headers(response.headers_hash)
        webmock_response
      end
      
      def build_easy_response(webmock_response)
        raise Curl::Err::TimeoutError if webmock_response.should_timeout        
        webmock_response.raise_error_if_any
        @response_body = webmock_response.body
        @webmock_response_code = webmock_response.status[0]
        
        @response_header = "HTTP/1.1 #{webmock_response.status[0]} #{webmock_response.status[1]}\r\n"
        if webmock_response.headers
          @response_header << webmock_response.headers.map do |k,v| 
            "#{k}: #{v.is_a?(Array) ? v.join(", ") : v}"
          end.join("\r\n")
        end
      end
      
      def auth_with_webmock=(auth)
        @webmock_auth = auth
        auth_without_webmock=(auth)
      end
      alias :auth_without_webmock= :auth=
      alias :auth= :auth_with_webmock=
      
      def response_code_with_webmock
        if @webmock_response_code
          @webmock_response_code
        else
          response_code_without_webmock
        end
      end
      alias :response_code_without_webmock :response_code
      alias :response_code :response_code_with_webmock
      
      def reset_with_webmock
        @webmock_auth = nil
        reset_without_webmock
      end
      alias :reset_without_webmock :reset
      alias :reset :reset_with_webmock
      
      def perform_with_webmock
        @webmock_response_code = nil
        request_signature = build_request_signature
        WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)
        if WebMock::StubRegistry.instance.registered_request?(request_signature)
          webmock_response = WebMock::StubRegistry.instance.response_for_request(request_signature)
          build_easy_response(webmock_response)
          WebMock::CallbackRegistry.invoke_callbacks(
            {:lib => :typhoeus}, request_signature, webmock_response)
          # invoke_curb_callbacks
          true
        elsif WebMock.net_connect_allowed?(request_signature.uri)
          res = perform_without_webmock
          if WebMock::CallbackRegistry.any_callbacks?
            webmock_response = build_webmock_response
            WebMock::CallbackRegistry.invoke_callbacks(
              {:lib => :typhoeus, :real_request => true}, request_signature,
                webmock_response)   
          end
          res
        else
          raise WebMock::NetConnectNotAllowedError.new(request_signature)
        end
      end
      alias :perform_without_webmock :perform
      alias :perform :perform_with_webmock
    end
    
    
  end
end