# frozen_string_literal: true

begin
  require 'typhoeus'
rescue LoadError
  # typhoeus not found
end

if defined?(Typhoeus)
  WebMock::VersionChecker.new('Typhoeus', Typhoeus::VERSION, '0.3.2').check_version!

  module WebMock
    module HttpLibAdapters
      class TyphoeusAdapter < HttpLibAdapter
        adapter_for :typhoeus

        def self.enable!
          @disabled = false
          add_before_callback
          add_after_request_callback
          ::Typhoeus::Config.block_connection = true
        end

        def self.disable!
          @disabled = true
          remove_after_request_callback
          remove_before_callback
          ::Typhoeus::Config.block_connection = false
        end

        def self.disabled?
          !!@disabled
        end

        def self.add_before_callback
          unless Typhoeus.before.include?(BEFORE_CALLBACK)
            Typhoeus.before << BEFORE_CALLBACK
          end
        end

        def self.remove_before_callback
          Typhoeus.before.delete_if {|v| v == BEFORE_CALLBACK }
        end

        def self.add_after_request_callback
          unless Typhoeus.on_complete.include?(AFTER_REQUEST_CALLBACK)
            Typhoeus.on_complete << AFTER_REQUEST_CALLBACK
          end
        end

        def self.remove_after_request_callback
          Typhoeus.on_complete.delete_if {|v| v == AFTER_REQUEST_CALLBACK }
        end

        def self.build_request_signature(req, url = req.url)
          uri = WebMock::Util::URI.heuristic_parse(url)
          uri.path = uri.normalized_path.gsub("[^:]//","/")

          headers = req.options[:headers]

          if req.options[:userpwd]
            headers['Authorization'] = WebMock::Util::Headers.basic_auth_header(req.options[:userpwd])
          end

          body = req.options[:body]

          if body.is_a?(Hash)
            body = WebMock::Util::QueryMapper.values_to_query(body)
          end

          request_signature = WebMock::RequestSignature.new(
            req.options[:method] || :get,
            uri.to_s,
            body: body,
            headers: headers
          )

          req.instance_variable_set(:@__webmock_request_signature, request_signature)

          request_signature
        end


        def self.build_webmock_response(typhoeus_response)
          webmock_response = WebMock::Response.new
          webmock_response.status = [typhoeus_response.code, typhoeus_response.status_message]
          webmock_response.body = typhoeus_response.body
          webmock_response.headers = typhoeus_response.headers
          webmock_response
        end

        def self.generate_typhoeus_response(webmock_response, url)
          response_options = if webmock_response.should_timeout
            {
              code: 0,
              status_message: "",
              body: "",
              headers: {},
              return_code: :operation_timedout,
              response_headers: ""
            }
          else
            {
              code: webmock_response.status[0],
              status_message: webmock_response.status[1],
              body: webmock_response.body,
              headers: webmock_response.headers,
              return_code: :ok,
              response_headers: response_headers_string(webmock_response)
            }
          end
          response = ::Typhoeus::Response.new(response_options.merge(
            effective_url: effective_url(url),
            total_time: 0.0,
            starttransfer_time: 0.0,
            appconnect_time: 0.0,
            pretransfer_time: 0.0,
            connect_time: 0.0,
            namelookup_time: 0.0,
            redirect_time: 0.0
          ))
          response.mock = :webmock
          response
        end

        # Without response_headers, Typhoeus builds them for a mocked response
        # from its return_code, as in "HTTP/1.1 ok Mock Reason Phrase".
        def self.response_headers_string(webmock_response)
          code, reason = webmock_response.status
          lines = ["HTTP/1.1 #{code} #{reason}"]
          (webmock_response.headers || {}).each do |name, values|
            Array(values).each { |value| lines << "#{name}: #{value}" }
          end
          # Bytes, as in a real response, so values in different encodings join.
          lines.map(&:b).join("\r\n") + "\r\n\r\n"
        end

        # The request URL as curl reports it: with its port, query and encoding as
        # given, but with a lower case scheme, http:// when there is none, dot
        # segments resolved, "/" for an empty path and no empty query or
        # fragment. Like curl's, it is a binary string.
        def self.effective_url(url)
          # A scheme needs at least one slash after it, so localhost:3000 has
          # none. heuristic_parse turns http:/ and http:/// into http://.
          url = "http://#{url}" unless url.match?(%r{\A[a-z][a-z0-9+.\-]*:/}i)
          uri = WebMock::Util::URI.heuristic_parse(url)
          uri.scheme = uri.scheme.downcase
          uri.path = Addressable::URI.normalize_path(uri.path)
          uri.path = "/" if uri.path.empty?
          uri.query = nil if uri.query == ""
          uri.fragment = nil if uri.fragment == ""
          uri.to_s.b
        end

        def self.request_hash(request_signature)
          hash = {}

          hash[:body]    = request_signature.body
          hash[:headers] = request_signature.headers

          hash
        end

        AFTER_REQUEST_CALLBACK = Proc.new do |response|
          request = response.request
          request_signature = request.instance_variable_get(:@__webmock_request_signature)
          webmock_response =
            ::WebMock::HttpLibAdapters::TyphoeusAdapter.
              build_webmock_response(response)
          if response.mock
            WebMock::CallbackRegistry.invoke_callbacks(
              {lib: :typhoeus},
              request_signature,
              webmock_response
            )
          else
            WebMock::CallbackRegistry.invoke_callbacks(
              {lib: :typhoeus, real_request: true},
              request_signature,
              webmock_response
            )
          end
        end

        BEFORE_CALLBACK = Proc.new do |request|
          Typhoeus::Expectation.all.delete_if {|e| e.from == :webmock }
          res = true

          unless WebMock::HttpLibAdapters::TyphoeusAdapter.disabled?
            # Typhoeus builds a curl handle to work out the URL, so do it once.
            url = request.url
            request_signature = ::WebMock::HttpLibAdapters::TyphoeusAdapter.build_request_signature(request, url)
            request.block_connection = false;

            ::WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

            if webmock_response = ::WebMock::StubRegistry.instance.response_for_request(request_signature)
              response = ::WebMock::HttpLibAdapters::TyphoeusAdapter.generate_typhoeus_response(webmock_response, url)
              if request.respond_to?(:on_headers)
                request.execute_headers_callbacks(response)
              end
              if request.respond_to?(:streaming?) && request.streaming?
                response.options[:response_body] = "".dup
                request.on_body.each { |callback| callback.call(webmock_response.body, response) }
              end
              request.finish(response)
              webmock_response.raise_error_if_any
              res = false
            elsif !WebMock.net_connect_allowed?(request_signature.uri)
              raise WebMock::NetConnectNotAllowedError.new(request_signature)
            end
          end
          res
        end
      end
    end
  end
end
