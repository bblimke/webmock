if defined?(EventMachine::HttpClient)

  module EventMachine
    OriginalHttpClient = HttpClient unless const_defined?(:OriginalHttpClient)

    class WebMockHttpClient < EventMachine::HttpClient
      include HttpEncoding

      def uri
        @req.uri
      end

      def setup(response, uri, error = nil)
        @last_effective_url = @uri = uri
        if error
          on_error(error)
          fail(self)
        else
          @conn.receive_data(response)
          succeed(self)
        end
      end

      def send_request_with_webmock(head, body)
        request_signature = build_request_signature

        WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

        if WebMock::StubRegistry.instance.registered_request?(request_signature)
          webmock_response = WebMock::StubRegistry.instance.response_for_request(request_signature)
          WebMock::CallbackRegistry.invoke_callbacks({:lib => :em_http_request}, request_signature, webmock_response)
          on_error("WebMock timeout error") if webmock_response.should_timeout
          setup(make_raw_response(webmock_response), @uri,
                webmock_response.should_timeout ? "WebMock timeout error" : nil)
          self
        elsif WebMock.net_connect_allowed?(request_signature.uri)
          send_request_without_webmock(head, body)
          callback {
            if WebMock::CallbackRegistry.any_callbacks?
              webmock_response = build_webmock_response
              WebMock::CallbackRegistry.invoke_callbacks(
                {:lib => :em_http_request, :real_request => true},
                request_signature,
                webmock_response)
            end
          }
          self
        else
          raise WebMock::NetConnectNotAllowedError.new(request_signature)
        end
      end

      alias_method :send_request_without_webmock, :send_request
      alias_method :send_request, :send_request_with_webmock


      private

      def build_webmock_response
        webmock_response = WebMock::Response.new
        webmock_response.status = [response_header.status, response_header.http_reason]
        webmock_response.headers = response_header
        webmock_response.body = response
        webmock_response
      end

      def build_request_signature
        method = @req.method
        uri = @req.uri
        auth = @req.proxy[:authorization]
        query = @req.query
        headers = @req.headers
        body = @req.body

        if auth
          userinfo = auth.join(':')
          userinfo = WebMock::Util::URI.encode_unsafe_chars_in_userinfo(userinfo)
          if @req
            @req.proxy.reject! {|k,v| t.to_s == 'authorization' }
          else
            options.reject! {|k,v| k.to_s == 'authorization' } #we added it to url userinfo
          end
          uri.userinfo = userinfo
        end

        uri.query = encode_query(@req.uri, query).slice(/\?(.*)/, 1)

        WebMock::RequestSignature.new(
          method.downcase.to_sym,
          uri.to_s,
          :body => body,
          :headers => headers
        )
      end


      def make_raw_response(response)
        response.raise_error_if_any

        status, headers, body = response.status, response.headers, response.body
        headers ||= {}

        response_string = []
        response_string << "HTTP/1.1 #{status[0]} #{status[1]}"

        headers["Content-Length"] = body.length unless headers["Content-Length"]
        headers.each do |header, value|
          value = value.join(", ") if value.is_a?(Array)

          # WebMock's internal processing will not handle the body
          # correctly if the header indicates that it is chunked, unless
          # we also create all the chunks.
          # It's far easier just to remove the header.
          next if header =~ /transfer-encoding/i && value =~/chunked/i

          response_string << "#{header}: #{value}"
        end if headers

        response_string << "" << body
        response_string.join("\n")
      end

      def self.activate!
        EventMachine.send(:remove_const, :HttpClient)
        EventMachine.send(:const_set, :HttpClient, WebMockHttpClient)
      end

      def self.deactivate!
        EventMachine.send(:remove_const, :HttpClient)
        EventMachine.send(:const_set, :HttpClient, OriginalHttpClient)
      end
    end
  end

  EventMachine::WebMockHttpClient.activate!
end
