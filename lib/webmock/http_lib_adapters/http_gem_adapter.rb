begin
  require "http"
rescue LoadError
  # HTTP gem not found
end


if defined?(HTTP::Client)
  module WebMock
    module HttpLibAdapters
      class HttpGemAdapter < HttpLibAdapter

        adapter_for :http_gem


        def self.enable!
          ::HTTP.enable_webmock!
        end


        def self.disable!
          ::HTTP.disable_webmock!
        end

      end
    end
  end


  module HTTP
    class Request

      def webmock_signature
        ::WebMock::RequestSignature.new(method, uri.to_s, {
          :headers  => headers,
          :body     => body
        })
      end

    end


    class Response

      def to_webmock
        webmock_response = ::WebMock::Response.new

        webmock_response.status  = [status, reason]
        webmock_response.body    = body.to_s
        webmock_response.headers = headers

        webmock_response
      end


      def self.from_webmock(webmock_response)
        status  = webmock_response.status.first
        headers = webmock_response.headers || {}
        body    = webmock_response.body

        new(status, "1.1", headers, body)
      end

    end


    class WebMockPerform

      def initialize request, &perform
        @request = request
        @perform = perform
      end


      def exec
        replay || perform || halt
      end


      def request_signature
        unless @request_signature
          @request_signature = @request.webmock_signature
          register_request(@request_signature)
        end

        @request_signature
      end


      protected


      def response_for_request(signature)
        ::WebMock::StubRegistry.instance.response_for_request(signature)
      end


      def register_request(signature)
        ::WebMock::RequestRegistry.instance.requested_signatures.put(signature)
      end


      def replay
        webmock_response = response_for_request(request_signature)

        return unless webmock_response

        raise Errno::ETIMEDOUT if webmock_response.should_timeout
        webmock_response.raise_error_if_any

        invoke_callbacks(webmock_response, :real_request => false)
        ::HTTP::Response.from_webmock webmock_response
      end


      def perform
        return unless ::WebMock.net_connect_allowed?(request_signature.uri)
        response = @perform.call
        invoke_callbacks(response.to_webmock, :real_request => true)
        response
      end


      def halt
        raise ::WebMock::NetConnectNotAllowedError.new request_signature
      end


      def invoke_callbacks webmock_response, options = {}
        ::WebMock::CallbackRegistry.invoke_callbacks(
          options.merge({ :lib => :http_gem }),
          request_signature,
          webmock_response
        )
      end

    end


    class Client

      alias :__perform__ :perform

      def perform request, options
        return __perform__(request, options) unless ::HTTP.webmock_enabled?
        WebMockPerform.new(request) { __perform__(request, options) }.exec
      end

    end


    class << self

      def enable_webmock!
        @webmock_enabled = true
      end


      def disable_webmock!
        @webmock_enabled = false
      end


      def webmock_enabled?
        @webmock_enabled
      end

    end
  end
end
