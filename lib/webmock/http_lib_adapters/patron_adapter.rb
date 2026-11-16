# frozen_string_literal: true

require 'stringio'

begin
  require 'patron'
rescue LoadError
  # patron not found
end

if defined?(::Patron::Session)
  module WebMock
    module HttpLibAdapters
      class PatronAdapter < ::WebMock::HttpLibAdapter
        adapter_for :patron

        OriginalPatronSession = ::Patron::Session unless const_defined?(:OriginalPatronSession)

        class WebMockPatronSession < ::Patron::Session
          def handle_request(req)
            request_signature =
              WebMock::HttpLibAdapters::PatronAdapter.build_request_signature(req)

            WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

            if webmock_response = WebMock::StubRegistry.instance.response_for_request(request_signature)
              WebMock::HttpLibAdapters::PatronAdapter.
                handle_file_name(req, webmock_response)
              res = WebMock::HttpLibAdapters::PatronAdapter.
                build_patron_response(webmock_response, default_response_charset)
              WebMock::CallbackRegistry.invoke_callbacks(
                {lib: :patron}, request_signature, webmock_response)
              res
            elsif WebMock.net_connect_allowed?(request_signature.uri)
              res = super
              if WebMock::CallbackRegistry.any_callbacks?
                webmock_response = WebMock::HttpLibAdapters::PatronAdapter.
                  build_webmock_response(res)
                WebMock::CallbackRegistry.invoke_callbacks(
                  {lib: :patron, real_request: true}, request_signature,
                    webmock_response)
              end
              res
            else
              raise WebMock::NetConnectNotAllowedError.new(request_signature)
            end
          end

          # Patron 1.1 sends #get_file and streamed requests past
          # #handle_request, so they are caught where they start
          if ::Patron::Session.public_method_defined?(:stream)
            def request(action, url, headers = {}, *positional, **options)
              all_options = options
              if positional.first.is_a?(Hash)
                all_options = positional.first.transform_keys(&:to_sym).merge(options)
              end
              file = all_options[:file]
              unless file && !all_options[:multipart] && action.to_s.casecmp?("get")
                return super
              end

              without_file = all_options.reject { |name, _| name == :file }
              req = build_request(action, url, headers, **without_file)
              WebMock::HttpLibAdapters::PatronAdapter.handle_streamed_request(req) do |webmock_response|
                if webmock_response
                  res = WebMock::HttpLibAdapters::PatronAdapter.
                    build_patron_response(webmock_response, default_response_charset)
                  File.open(file, "wb") { |f| f.write(webmock_response.body) }
                  res
                else
                  super
                end
              end
            end

            def stream(action, url, headers = {}, **options, &block)
              return super unless block

              req = build_request(action, url, headers, **options)
              WebMock::HttpLibAdapters::PatronAdapter.handle_streamed_request(req) do |webmock_response, request_signature|
                if webmock_response
                  WebMock::HttpLibAdapters::PatronAdapter.
                    stream_stubbed_response(webmock_response, request_signature, default_response_charset, &block)
                else
                  super
                end
              end
            end
          end
        end

        # Stands in for the Patron::ResponseStream that Patron::Session#stream
        # yields, reading a stubbed body
        class StubbedResponseStream
          CHUNK_SIZE = 64 * 1024

          HEAD_READERS = [:url, :status, :status_line, :redirect_count, :headers,
                          :charset, :ok?, :error?, :content_length, :content_type].freeze

          HEAD_READERS.each do |name|
            define_method(name) { @head.public_send(name) }
          end

          def initialize(head, body)
            @head = head
            @body = StringIO.new(body.to_s.b)
            @closed = false
          end

          def read(length = nil, outbuf = nil)
            ensure_open!
            outbuf ? @body.read(length, outbuf) : @body.read(length)
          end

          def readpartial(maxlen, outbuf = nil)
            ensure_open!
            outbuf ? @body.readpartial(maxlen, outbuf) : @body.readpartial(maxlen)
          end

          def each
            return enum_for(:each) unless block_given?
            ensure_open!
            while (chunk = @body.read(CHUNK_SIZE))
              yield chunk
            end
            self
          end

          def each_line(&block)
            return enum_for(:each_line) unless block
            ensure_open!
            @body.each_line(&block)
            self
          end

          def drain!
            ensure_open!
            @body.read.bytesize
          end

          def eof?
            ensure_open!
            @body.eof?
          end
          alias eof eof?

          def close
            @closed = true
            nil
          end

          def closed?
            @closed
          end

          def downloaded_bytes
            @body.pos
          end

          def complete?
            @body.eof?
          end

          def inspect
            "#<#{self.class.name} @status_line='#{status_line}'#{' (closed)' if @closed}>"
          end

          private

          def ensure_open!
            raise IOError, "closed stream" if @closed
          end
        end

        def self.enable!
          Patron.send(:remove_const, :Session)
          Patron.send(:const_set, :Session, WebMockPatronSession)
        end

        def self.disable!
          Patron.send(:remove_const, :Session)
          Patron.send(:const_set, :Session, OriginalPatronSession)
        end

        def self.handle_file_name(req, webmock_response)
          if req.action == :get && req.file_name
            begin
              File.open(req.file_name, "w") do |f|
                f.write webmock_response.body
              end
            rescue Errno::EACCES
              raise ArgumentError.new("Unable to open specified file.")
            end
          end
        end

        def self.build_request_signature(req)
          uri = WebMock::Util::URI.heuristic_parse(req.url)
          uri.path = uri.normalized_path.gsub("[^:]//","/")

          if [:put, :post, :patch].include?(req.action)
            if req.file_name
              if !File.exist?(req.file_name) || !File.readable?(req.file_name)
                raise ArgumentError.new("Unable to open specified file.")
              end
              request_body = File.read(req.file_name)
            elsif req.upload_data
              request_body = req.upload_data
            else
              raise ArgumentError.new("Must provide either data or a filename when doing a PUT or POST")
            end
          end

          headers = req.headers

          if req.credentials
            headers['Authorization'] = WebMock::Util::Headers.basic_auth_header(req.credentials)
          end

          request_signature = WebMock::RequestSignature.new(
            req.action,
            uri.to_s,
            body: request_body,
            headers: headers
          )
          request_signature
        end

        def self.build_patron_response(webmock_response, default_response_charset)
          raise ::Patron::TimeoutError if webmock_response.should_timeout
          webmock_response.raise_error_if_any

          header_fields = (webmock_response.headers || []).map { |(k, vs)| Array(vs).map { |v| "#{k}: #{v}" } }.flatten
          status_line   = "HTTP/1.1 #{webmock_response.status[0]} #{webmock_response.status[1]}"
          header_data   = ([status_line] + header_fields).join("\r\n")

          ::Patron::Response.new(
            "".dup,
            webmock_response.status[0],
            0,
            header_data,
            webmock_response.body.dup,
            default_response_charset
          )
        end

        # Yields the stubbed response for req, or nil when a real request is
        # allowed, and returns what the block does
        def self.handle_streamed_request(req)
          request_signature = build_request_signature(req)
          WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

          if webmock_response = WebMock::StubRegistry.instance.response_for_request(request_signature)
            result = yield webmock_response, request_signature
            WebMock::CallbackRegistry.invoke_callbacks(
              {lib: :patron}, request_signature, webmock_response)
            result
          elsif WebMock.net_connect_allowed?(request_signature.uri)
            result = yield nil, request_signature
            if WebMock::CallbackRegistry.any_callbacks?
              WebMock::CallbackRegistry.invoke_callbacks(
                {lib: :patron, real_request: true}, request_signature,
                  build_webmock_response(result))
            end
            result
          else
            raise WebMock::NetConnectNotAllowedError.new(request_signature)
          end
        end

        def self.stream_stubbed_response(webmock_response, request_signature, default_response_charset)
          head = build_patron_response(webmock_response, default_response_charset)
          stream = StubbedResponseStream.new(head, webmock_response.body)
          begin
            yield stream
          ensure
            stream.close
          end

          ::Patron::TransferStats.new(
            url: head.url,
            status: head.status,
            redirect_count: head.redirect_count,
            header_data: build_header_data(webmock_response),
            downloaded_bytes: stream.downloaded_bytes,
            uploaded_bytes: request_signature.body.to_s.bytesize,
            timings: {},
            complete: stream.complete?,
            default_charset: default_response_charset
          )
        end

        def self.build_header_data(webmock_response)
          header_fields = (webmock_response.headers || []).map { |(k, vs)| Array(vs).map { |v| "#{k}: #{v}" } }.flatten
          status_line   = "HTTP/1.1 #{webmock_response.status[0]} #{webmock_response.status[1]}"
          ([status_line] + header_fields).join("\r\n")
        end

        # Takes a Patron::Response, or the Patron::TransferStats of a streamed
        # request, which has no body
        def self.build_webmock_response(patron_response)
          webmock_response = WebMock::Response.new
          reason = patron_response.status_line.
            scan(%r(\AHTTP/(\d+(?:\.\d+)?)\s+(\d\d\d)\s*([^\r\n]+)?))[0][2]
          webmock_response.status = [patron_response.status, reason]
          webmock_response.body = patron_response.body if patron_response.respond_to?(:body)
          webmock_response.headers = patron_response.headers
          webmock_response
        end
      end
    end
  end
end
