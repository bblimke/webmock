if defined?(Curl)

  module Curl
    class Easy
      def http_with_webmock(method)
        request_signature = build_request_signature(method)

        WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

        if WebMock.registered_request?(request_signature)
          webmock_response = WebMock.response_for_request(request_signature)
          build_curb_response(webmock_response)
          WebMock::CallbackRegistry.invoke_callbacks(
            {:lib => :curb}, request_signature, webmock_response)
          true
        elsif WebMock.net_connect_allowed?(request_signature.uri)
          res = http_without_webmock(method.to_s)
          if WebMock::CallbackRegistry.any_callbacks?
            webmock_response = build_webmock_response
            WebMock::CallbackRegistry.invoke_callbacks(
              {:lib => :curb, :real_request => true}, request_signature,
                webmock_response)   
          end
          res
        else
          raise WebMock::NetConnectNotAllowedError.new(request_signature)
        end
      end

      alias_method :http_without_webmock, :http
      alias_method :http, :http_with_webmock

      def build_request_signature(method)
        uri = WebMock::Util::URI.heuristic_parse(self.url)
        uri.path = uri.normalized_path.gsub("[^:]//","/")
        uri.user = self.username
        uri.password = self.password

        request_body = case method
        when :post
          self.post_body
        else
          nil
        end

        request_signature = WebMock::RequestSignature.new(
          method,
          uri.to_s,
          :body => request_body,
          :headers => self.headers
        )
        request_signature
      end
      
      def build_curb_response(webmock_response)
        raise Curl::Err::TimeoutError if webmock_response.should_timeout        
        webmock_response.raise_error_if_any
        
        @body_str = webmock_response.body
        @response_code = webmock_response.status[0]

        @header_str = "HTTP/1.1 #{webmock_response.status[0]} #{webmock_response.status[1]}\r\n"
        if webmock_response.headers
          @header_str << webmock_response.headers.map {|k,v| "#{k}: #{v}" }.join("\r\n")
        end
      end

      def body_str_with_webmock
        @body_str || body_str_without_webmock
      end
      alias :body_str_without_webmock :body_str
      alias :body_str :body_str_with_webmock

      def response_code_with_webmock
        @response_code || response_code_without_webmock
      end
      alias :response_code_without_webmock :response_code
      alias :response_code :response_code_with_webmock

      def header_str_with_webmock
        @header_str || header_str_without_webmock
      end
      alias :header_str_without_webmock :header_str
      alias :header_str :header_str_with_webmock


      
      def build_webmock_response
        status, headers = WebmockHelper.parse_header_string(self.header_str)

        webmock_response = WebMock::Response.new
        webmock_response.status = [self.response_code, status]
        webmock_response.body = self.body_str
        webmock_response.headers = headers
        webmock_response
      end
  
      module WebmockHelper
        # Borrowed from Patron:
        # http://github.com/toland/patron/blob/master/lib/patron/response.rb
        def self.parse_header_string(header_string)
          status, headers = nil, {}

          header_string.split(/\r\n/).each do |header|
            if header =~ %r|^HTTP/1.[01] \d\d\d (.*)|
              status = $1
            else
              parts = header.split(':', 2)
              unless parts.empty?
                parts[1].strip! unless parts[1].nil?
                if headers.has_key?(parts[0])
                  headers[parts[0]] = [headers[parts[0]]] unless headers[parts[0]].kind_of? Array
                  headers[parts[0]] << parts[1]
                else
                  headers[parts[0]] = parts[1]
                end
              end
            end
          end

          return status, headers
        end
      end

    end
  end

end
