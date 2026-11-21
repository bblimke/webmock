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

        # Patron 1.0 moved Response.new to keyword arguments, see https://github.com/toland/patron/issues/209
        PATRON_RESPONSE_TAKES_KEYWORDS =
          ::Patron::Response.instance_method(:initialize).parameters.include?([:keyreq, :url])

        class WebMockPatronSession < ::Patron::Session
          def handle_request(req)
            request_signature, webmock_response = PatronAdapter.register_request(req)

            if webmock_response
              PatronAdapter.handle_file_name(req, webmock_response)
              res = PatronAdapter.build_patron_response(webmock_response, default_response_charset)
              PatronAdapter.invoke_callbacks(request_signature, webmock_response)
              res
            else
              res = super
              PatronAdapter.invoke_real_request_callbacks(request_signature, res)
              res
            end
          end

          # Patron 1.1 sends #get_file and streamed requests past
          # #handle_request
          if ::Patron::Session.public_method_defined?(:stream)
            def stream(action, url, headers = {}, **options, &block)
              return super unless block

              req = build_request(action, url, headers, **options)
              request_signature, webmock_response = PatronAdapter.register_request(req)

              if webmock_response
                PatronAdapter.stream_stubbed_response(webmock_response, request_signature,
                  default_response_charset, &block)
              else
                # Callbacks run once the head has arrived, so they also run
                # when the block leaves before the end of the body
                super(action, url, headers, **options) do |stream|
                  PatronAdapter.invoke_real_request_callbacks(request_signature, stream)
                  yield stream
                end
              end
            end

            private

            # Called by #get_file, and by #request for a GET with a file
            def download(req, path)
              request_signature, webmock_response = PatronAdapter.register_request(req)

              if webmock_response
                # Like Patron, with the body in the file only
                res = PatronAdapter.build_patron_response(webmock_response, default_response_charset, with_body: false)
                File.open(path, "wb") { |f| f.write(webmock_response.body) }
                PatronAdapter.invoke_callbacks(request_signature, webmock_response)
                res
              else
                res = super
                PatronAdapter.invoke_real_request_callbacks(request_signature, res)
                res
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
            @body = body
            @closed = false
          end

          def read(length = nil, outbuf = nil)
            ensure_open!
            @body.read(length, outbuf)
          end

          def readpartial(maxlen, outbuf = nil)
            ensure_open!
            @body.readpartial(maxlen, outbuf)
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
            data = req.upload_data
            path = req.file_name || (data.to_path if data.respond_to?(:to_path))
            if path
              if !File.exist?(path) || !File.readable?(path)
                raise ArgumentError.new("Unable to open specified file.")
              end
              # A named pipe or device must be left for Patron to open.
              request_body = File.file?(path) ? File.binread(path) : path.to_s
            elsif data.respond_to?(:read) && OriginalPatronSession.public_method_defined?(:stream)
              # Patron 1.1 added streaming uploads and Session#stream together.
              request_body = WebMock::Util::UploadBody.read(data, req.headers)
            elsif data
              request_body = data.to_s
            else
              raise ArgumentError.new("Must provide either data or a filename when doing a PUT or POST")
            end
          end

          # A copy, so the Authorization header added below for matching is
          # not sent with a real request
          headers = req.headers.dup

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

        def self.build_patron_response(webmock_response, default_response_charset, with_body: true)
          raise ::Patron::TimeoutError if webmock_response.should_timeout
          webmock_response.raise_error_if_any

          header_data = build_header_data(webmock_response)

          if PATRON_RESPONSE_TAKES_KEYWORDS
            ::Patron::Response.new(
              url: "".dup,
              status: webmock_response.status[0],
              redirect_count: 0,
              header_data: header_data,
              body: with_body ? webmock_response.body.dup : nil,
              default_charset: default_response_charset
            )
          else
            ::Patron::Response.new(
              "".dup,
              webmock_response.status[0],
              0,
              header_data,
              webmock_response.body.dup,
              default_response_charset
            )
          end
        end

        # Records the request and returns its signature with the stubbed
        # response, which is nil when a real request is allowed
        def self.register_request(req)
          request_signature = build_request_signature(req)
          WebMock::RequestRegistry.instance.put(request_signature)

          webmock_response = WebMock::StubRegistry.instance.response_for_request(request_signature)
          if webmock_response.nil? && !WebMock.net_connect_allowed?(request_signature.uri)
            raise WebMock::NetConnectNotAllowedError.new(request_signature)
          end

          [request_signature, webmock_response]
        end

        def self.invoke_callbacks(request_signature, webmock_response)
          WebMock::CallbackRegistry.invoke_callbacks(
            {lib: :patron}, request_signature, webmock_response)
        end

        def self.invoke_real_request_callbacks(request_signature, patron_response)
          return unless WebMock::CallbackRegistry.any_callbacks?

          WebMock::CallbackRegistry.invoke_callbacks(
            {lib: :patron, real_request: true}, request_signature,
              build_webmock_response(patron_response))
        end

        # Callbacks run before the block, so they also run when it leaves
        # before the end of the body
        def self.stream_stubbed_response(webmock_response, request_signature, default_response_charset)
          head = build_patron_response(webmock_response, default_response_charset, with_body: false)
          invoke_callbacks(request_signature, webmock_response)
          # Kept out of the stream, so the stream has only the methods of
          # Patron::ResponseStream
          body = StringIO.new(webmock_response.body.to_s.b)
          stream = StubbedResponseStream.new(head, body)
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
            downloaded_bytes: body.pos,
            uploaded_bytes: request_signature.body.to_s.bytesize,
            timings: {},
            complete: body.eof?,
            default_charset: default_response_charset
          )
        end

        def self.build_header_data(webmock_response)
          header_fields = (webmock_response.headers || []).map { |(k, vs)| Array(vs).map { |v| "#{k}: #{v}" } }.flatten
          status_line   = "HTTP/1.1 #{webmock_response.status[0]} #{webmock_response.status[1]}"
          ([status_line] + header_fields).join("\r\n")
        end

        # Takes a Patron::Response, or the Patron::ResponseStream of a streamed
        # request, whose body is not read here
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
