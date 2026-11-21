# frozen_string_literal: true

begin
  require 'httpclient'
  require 'jsonclient' # defined in 'httpclient' gem as well
rescue LoadError
  # httpclient not found
  # or jsonclient not defined (in old versions of httclient gem)
end

if defined?(::HTTPClient)

  module WebMock
    module HttpLibAdapters
      class HTTPClientAdapter < HttpLibAdapter
        adapter_for :httpclient

        unless const_defined?(:OriginalHttpClient)
          OriginalHttpClient = ::HTTPClient
        end

        unless const_defined?(:OriginalJsonClient)
          OriginalJsonClient = ::JSONClient if defined?(::JSONClient)
        end

        def self.enable!
          Object.send(:remove_const, :HTTPClient)
          Object.send(:const_set, :HTTPClient, WebMockHTTPClient)
          if defined? ::JSONClient
            Object.send(:remove_const, :JSONClient)
            Object.send(:const_set, :JSONClient, WebMockJSONClient)
          end
        end

        def self.disable!
          Object.send(:remove_const, :HTTPClient)
          Object.send(:const_set, :HTTPClient, OriginalHttpClient)
          if defined? ::JSONClient
            Object.send(:remove_const, :JSONClient)
            Object.send(:const_set, :JSONClient, OriginalJsonClient)
          end
        end
      end
    end
  end

  module WebMockHTTPClients
    # HTTPClient publishes the response through push. Some versions return
    # a different value from do_get_stream, including nil for loopback replies.
    class AsyncConnection < ::HTTPClient::Connection
      attr_reader :response

      def push(response)
        @response = response
        super
      end
    end

    class ResponseFilter < Struct.new(:filter)
      def filter_request(_req)
      end

      def filter_response(req, response)
        filter.filter_response(req, response)
      end
    end
    private_constant :AsyncConnection, :ResponseFilter

    def do_get_block(req, proxy, conn, &block)
      @request_filter.each { |filter| filter.filter_request(req) }
      request_signature = build_request_signature(req)
      WebMock::RequestRegistry.instance.put(request_signature)
      webmock_response = WebMock::StubRegistry.instance.response_for_request(request_signature)
      if webmock_response
        response = build_httpclient_response(webmock_response, false, req.header, &block)
        @request_filter.each do |filter|
          filter.filter_response(req, response)
        end
        res = conn.push(response)
        WebMock::CallbackRegistry.invoke_callbacks(
          {lib: :httpclient}, request_signature, webmock_response)
        res
      elsif WebMock.net_connect_allowed?(request_signature.uri)
        if block
          body = ''
          do_get_block_without_webmock(req, proxy, conn) do |http_res, chunk|
            if chunk && chunk.bytesize > 0
              body += chunk
              block.call(http_res, chunk)
            end
          end
        else
          do_get_block_without_webmock(req, proxy, conn)
        end
        res = conn.pop
        conn.push(res)
        if WebMock::CallbackRegistry.any_callbacks?
          webmock_response = build_webmock_response(res, body)
          WebMock::CallbackRegistry.invoke_callbacks(
            {lib: :httpclient, real_request: true}, request_signature,
            webmock_response)
        end
        res
      else
        raise WebMock::NetConnectNotAllowedError.new(request_signature)
      end
    end

    def do_request_async(method, uri, query, body, extheader)
      req = create_request(method, uri, query, body, extheader)
      proxy = no_proxy?(uri) ? nil : @proxy
      filters = apply_request_filters(req, proxy)
      request_signature = build_request_signature(req)
      WebMock::RequestRegistry.instance.put(request_signature)

      webmock_response = WebMock::StubRegistry.instance.response_for_request(request_signature)
      unless webmock_response || WebMock.net_connect_allowed?(request_signature.uri)
        raise WebMock::NetConnectNotAllowedError.new(request_signature)
      end

      # Keep the prepared request, including any headers its filters assigned.
      # HTTPClient's do_request_async would create a second request in the worker.
      conn = AsyncConnection.new
      conn.async_thread = Thread.new do
        begin
          if webmock_response
            response = build_httpclient_response(webmock_response, true, req.header)
            filters.each { |filter| filter.filter_response(req, response) }
            conn.push(response)
            WebMock::CallbackRegistry.invoke_callbacks({lib: :httpclient}, request_signature, webmock_response)
          else
            clone(freeze: false).send_prepared_request(req, proxy, conn, filters)
            if WebMock::CallbackRegistry.any_callbacks?
              WebMock::CallbackRegistry.invoke_callbacks(
                {lib: :httpclient, real_request: true}, request_signature, build_webmock_response(conn.response))
            end
          end
        rescue Exception => e
          conn.push e
        end
      end
      conn
    end

    def build_httpclient_response(webmock_response, stream = false, req_header = nil, &block)
      body = stream ? StringIO.new(webmock_response.body) : webmock_response.body
      response = HTTP::Message.new_response(body, req_header)
      response.header.init_response(webmock_response.status[0])
      response.reason=webmock_response.status[1]
      webmock_response.headers.to_a.each { |name, value| response.header.set(name, value) }

      raise HTTPClient::TimeoutError if webmock_response.should_timeout
      webmock_response.raise_error_if_any

      block.call(response, body) if block && body && body.bytesize > 0

      response
    end

    def build_webmock_response(httpclient_response, body = nil)
      webmock_response = WebMock::Response.new
      webmock_response.status = [httpclient_response.status, httpclient_response.reason]

      webmock_response.headers = {}.tap do |hash|
        httpclient_response.header.all.each do |(key, value)|
          if hash.has_key?(key)
            hash[key] = Array(hash[key]) + [value]
          else
            hash[key] = value
          end
        end
      end

      if body
        webmock_response.body = body
      elsif httpclient_response.content.respond_to?(:read)
        webmock_response.body = httpclient_response.content.read
        body = HTTP::Message::Body.new
        body.init_response(StringIO.new(webmock_response.body))
        httpclient_response.body = body
      else
        webmock_response.body = httpclient_response.content
      end
      webmock_response
    end

    def build_request_signature(req)
      uri = WebMock::Util::URI.heuristic_parse(req.header.request_uri.to_s)
      if req.header.request_query
        # HTTPClient sends the query argument after the query in the URI
        query = WebMock::Util::QueryMapper.values_to_query(req.header.request_query, notation: WebMock::Config.instance.query_values_notation)
        uri.query = [uri.query, query].reject { |part| part.to_s.empty? }.join('&')
      end
      uri.port = req.header.request_uri.port

      headers = req.header.all.inject({}) do |hdrs, header|
        hdrs[header[0]] ||= []
        hdrs[header[0]] << header[1]
        hdrs
      end
      headers = headers_from_session(uri).merge(headers)

      WebMock::RequestSignature.new(
        req.header.request_method.downcase.to_sym,
        uri.to_s,
        body: req.http_body.dump,
        headers: headers
      )
    end

    protected

    # Only the per-request copy changes its filter list. It shares the client's
    # sessions and lets HTTPClient run the response filters at the normal time.
    def send_prepared_request(req, proxy, conn, filters)
      @request_filter = filters.map { |filter| ResponseFilter.new(filter) }
      protect_keep_alive_disconnected { do_get_stream(req, proxy, conn) }
    end

    private

    def apply_request_filters(req, proxy)
      # Recent HTTPClient versions select the applicable proxy filters here.
      return filter_request(req, proxy) if respond_to?(:filter_request, true)

      @request_filter.each { |filter| filter.filter_request(req) }
    end

    # some of the headers sent by HTTPClient are derived from
    # the client session
    def headers_from_session(uri)
      session_headers = HTTP::Message::Headers.new
      @session_manager.send(:open, uri).send(:set_header, MessageMock.new(session_headers))
      session_headers.all.inject({}) do |hdrs, header|
        hdrs[header[0]] = header[1]
        hdrs
      end
    end
  end

  class WebMockHTTPClient < HTTPClient
    alias_method :do_get_block_without_webmock, :do_get_block

    include WebMockHTTPClients
  end

  if defined? ::JSONClient
    class WebMockJSONClient < JSONClient
      alias_method :do_get_block_without_webmock, :do_get_block

      include WebMockHTTPClients
    end
  end


  # Mocks a HTTPClient HTTP::Message
  class MessageMock
    attr_reader :header

    def initialize(headers)
      @header = headers
    end

    def http_version=(value);end
  end

end
