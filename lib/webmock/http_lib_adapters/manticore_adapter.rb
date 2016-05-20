begin
  require 'manticore'
rescue LoadError
  # manticore not found
end

if defined?(Manticore)
  module WebMock
    module HttpLibAdapters
      class ManticoreAdapter < HttpLibAdapter
        adapter_for :manticore

        OriginalManticoreClient = Manticore::Client

        def self.enable!
          Manticore.send(:remove_const, :Client)
          Manticore.send(:const_set, :Client, WebMockManticoreClient)
          Manticore.instance_variable_set(:@manticore_facade, WebMockManticoreClient.new)
        end

        def self.disable!
          Manticore.send(:remove_const, :Client)
          Manticore.send(:const_set, :Client, OriginalManticoreClient)
          Manticore.instance_variable_set(:@manticore_facade, OriginalManticoreClient.new)
        end

        class WebMockManticoreClient < Manticore::Client
          def request(klass, url, options={}, &block)
            super(klass, WebMock::Util::URI.normalize_uri(url).to_s, format_options(options))
          end

          private

          def format_options(options)
            return options unless headers = options[:headers]

            options.merge(headers: join_array_values(headers))
          end

          def join_array_values(headers)
            headers.reduce({}) do |h, (k,v)|
              v = v.join(', ') if v.is_a?(Array)
              h.merge(k => v)
            end
          end

          def response_object_for(request, context, &block)
            request_signature = generate_webmock_request_signature(request, context)
            WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

            if webmock_response = registered_response_for(request_signature)
              webmock_response.raise_error_if_any
              manticore_response = generate_manticore_response(webmock_response).call
              real_request = false

            elsif real_request_allowed?(request_signature.uri)
              manticore_response = Manticore::Response.new(self, request, context, &block).call
              webmock_response = generate_webmock_response(manticore_response)
              real_request = true

            else
              raise WebMock::NetConnectNotAllowedError.new(request_signature)
            end

            WebMock::CallbackRegistry.invoke_callbacks({lib: :manticore, real_request: real_request}, request_signature, webmock_response)
            manticore_response
          end

          def registered_response_for(request_signature)
            WebMock::StubRegistry.instance.response_for_request(request_signature)
          end

          def real_request_allowed?(uri)
            WebMock.net_connect_allowed?(uri)
          end

          def generate_webmock_request_signature(request, context)
            method = request.method.downcase
            uri = request.uri.to_s
            body = read_body(request)
            headers = split_array_values(request.headers)

            if context.get_credentials_provider && credentials = context.get_credentials_provider.get_credentials(AuthScope::ANY)
              headers['Authorization'] = WebMock::Util::Headers.basic_auth_header(credentials.get_user_name,credentials.get_password)
            end

            WebMock::RequestSignature.new(method, uri, {body: body, headers: headers})
          end

          def read_body(request)
            if request.respond_to?(:entity) && !request.entity.nil?
              Manticore::EntityConverter.new.read_entity(request.entity)
            end
          end

          def split_array_values(headers = [])
            headers.each_with_object({}) do |(k, v), h|
              h[k] = case v
                     when /,/ then v.split(',').map(&:strip)
                     else v
                     end
            end
          end

          def generate_manticore_response(webmock_response)
            raise Manticore::ConnectTimeout if webmock_response.should_timeout

            Manticore::StubbedResponse.stub(
              code: webmock_response.status[0],
              body: webmock_response.body,
              headers: webmock_response.headers,
              cookies: {}
            )
          end

          def generate_webmock_response(manticore_response)
            webmock_response = WebMock::Response.new
            webmock_response.status = [manticore_response.code, manticore_response.message]
            webmock_response.body = manticore_response.body
            webmock_response.headers = manticore_response.headers
            webmock_response
          end
        end
      end
    end
  end
end
