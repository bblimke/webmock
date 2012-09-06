if defined?(EventMachine::HttpRequest)
  module WebMock
    module HttpLibAdapters
      class EmHttpRequestAdapter < HttpLibAdapter
        adapter_for :em_http_request

        OriginalHttpRequest = EventMachine::HttpRequest unless const_defined?(:OriginalHttpRequest)

        def self.enable!
          EventMachine.send(:remove_const, :HttpRequest)
          EventMachine.send(:const_set, :HttpRequest, EventMachine::WebMockHttpRequest)
        end

        def self.disable!
          EventMachine.send(:remove_const, :HttpRequest)
          EventMachine.send(:const_set, :HttpRequest, OriginalHttpRequest)
        end
      end
    end
  end


  module EventMachine
    class WebMockHttpRequest < EventMachine::HttpRequest

      include HttpEncoding

      class WebMockHttpClient < EventMachine::HttpClient

        def setup(response, uri, error = nil)
          @last_effective_url = @uri = uri
          if error
            on_error(error)
            fail(self)
          else
            EM.next_tick do
              receive_data(response)
              succeed(self)
            end
          end
        end

        def unbind
        end

        def close_connection
        end
      end

      def send_request(&block)
        request_signature = build_request_signature

        WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

        if webmock_response = WebMock::StubRegistry.instance.response_for_request(request_signature)
          WebMock::CallbackRegistry.invoke_callbacks(
          {:lib => :em_http_request}, request_signature, webmock_response)
          client = WebMockHttpClient.new(nil)
          client.on_error("WebMock timeout error") if webmock_response.should_timeout
          client.setup(make_raw_response(webmock_response), @uri,
            webmock_response.should_timeout ? "WebMock timeout error" : nil)
          client
        elsif WebMock.net_connect_allowed?(request_signature.uri)
          http = super
          http.callback {
            if WebMock::CallbackRegistry.any_callbacks?
              webmock_response = build_webmock_response(http)
              WebMock::CallbackRegistry.invoke_callbacks(
                {:lib => :em_http_request, :real_request => true}, request_signature,
                webmock_response)
            end
          }
          http
        else
          raise WebMock::NetConnectNotAllowedError.new(request_signature)
        end
      end

      private

      def build_webmock_response(http)
        webmock_response = WebMock::Response.new
        webmock_response.status = [http.response_header.status, http.response_header.http_reason]
        webmock_response.headers = http.response_header
        webmock_response.body = http.response
        webmock_response
      end

      def build_request_signature
        if @req
          options = @req.options
          method = @req.method
          uri = @req.uri.dup
        else
          options = @options
          method = @method
          uri = @uri.dup
        end

        if options[:authorization] || options['authorization']
          auth = (options[:authorization] || options['authorization'])
          userinfo = auth.join(':')
          userinfo = WebMock::Util::URI.encode_unsafe_chars_in_userinfo(userinfo)
          options.reject! {|k,v| k.to_s == 'authorization' } #we added it to url userinfo
          uri.userinfo = userinfo
        end

        uri.query = encode_query(@req.uri, options[:query]).slice(/\?(.*)/, 1)

        body = options[:body] || options['body']
        body = form_encode_body(body) if body.is_a?(Hash)

        WebMock::RequestSignature.new(
          method.downcase.to_sym,
          uri.to_s,
          :body => body,
          :headers => (options[:head] || options['head'])
        )
      end


      def make_raw_response(response)
        response.raise_error_if_any

        status, headers, body = response.status, response.headers, response.body

        response_string = []
        response_string << "HTTP/1.1 #{status[0]} #{status[1]}"

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
    end
  end
end
