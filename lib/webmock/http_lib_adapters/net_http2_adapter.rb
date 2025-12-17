require 'net-http2'

module WebMock
  module HttpLibAdapters
    class NetHttp2Adapter < HttpLibAdapter
      adapter_for :net_http2

      OriginalClient = NetHttp2::Client unless const_defined?(:OriginalClient)
      OriginalStream = NetHttp2::Stream unless const_defined?(:OriginalStream)

      def self.enable!
        NetHttp2.send(:remove_const, :Stream)
        NetHttp2.send(:remove_const, :Client)
        NetHttp2.send(:const_set, :Stream, @webMockNetHTTP2Stream)
        NetHttp2.send(:const_set, :Client, @webMockNetHTTP2Client)
      end

      def self.disable!
        NetHttp2.send(:remove_const, :Stream)
        NetHttp2.send(:remove_const, :Client)
        NetHttp2.send(:const_set, :Stream, OriginalStream)
        NetHttp2.send(:const_set, :Client, OriginalClient)
      end

      @webMockNetHTTP2Stream = Class.new(OriginalStream) do
        def initialize(*)
          @webmock_queue = Queue.new
          super
        end

        def send_request_data
          uri = @request.uri.dup
          uri.path = @request.full_path.to_s
          sig = WebMock::RequestSignature.new(@request.method, uri.to_s, body: @request.body, headers: @request.headers)
          WebMock::RequestRegistry.instance.requested_signatures.put(sig)

          if webmock_response = WebMock::StubRegistry.instance.response_for_request(sig)
            WebMock::CallbackRegistry.invoke_callbacks({ lib: :net_http2 }, sig, webmock_response)
            return if webmock_response.should_timeout

            if async?
              @request.emit(:headers, webmock_response.headers.merge(":status" => webmock_response.status.first.to_s))
              @request.emit(:body_chunk, webmock_response.body)
              @request.emit(:close, nil)
            else
              @headers.merge!((webmock_response.headers || {}).merge(":status" => webmock_response.status.first.to_s))
              @data << webmock_response.body
              @completed = true
              Thread.new do
                @webmock_queue.pop
                @mutex.synchronize { @cv.signal }
              end
            end
          elsif WebMock.net_connect_allowed?(sig.uri)
            raise "WebMock NetHTTP2 backend does not support net_connect_allowed yet"
          else
            raise WebMock::NetConnectNotAllowedError, sig
          end
        end

        def wait_for_completed
          @mutex.synchronize do
            @webmock_queue.push(:waiting)
            @cv.wait(@mutex, @request.timeout)
          end
        end
      end

      @webMockNetHTTP2Client = Class.new(OriginalClient) do
        def new_socket
          StubSocket.new
        end
      end
    end
  end
end
