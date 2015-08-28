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
            @method = KLASS_TO_METHOD.fetch(klass)
            @uri = url
            @options = options
            super(klass, WebMock::Util::URI.normalize_uri(url).to_s, format_options(options))
          end

          private

          KLASS_TO_METHOD = {
            Java::OrgManticore::HttpGetWithEntity => :get,
            Java::OrgApacheHttpClientMethods::HttpPut => :put,
            Java::OrgApacheHttpClientMethods::HttpHead => :head,
            Java::OrgApacheHttpClientMethods::HttpPost => :post,
            Java::OrgApacheHttpClientMethods::HttpDelete => :delete,
            Java::OrgApacheHttpClientMethods::HttpOptions => :options,
            Java::OrgApacheHttpClientMethods::HttpPatch => :patch
          }

          def format_options(options)
            return options unless headers = options[:headers]

            options.merge(:headers => join_array_values(headers))
          end

          def join_array_values(headers)
            headers.reduce({}) do |h, (k,v)|
              v = v.join(', ') if v.is_a?(Array)
              h.merge(k => v)
            end
          end

          def response_object_for(client, request, context, &block)
            request_signature = generate_webmock_request_signature
            WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

            if webmock_response = registered_response_for(request_signature)
              webmock_response.raise_error_if_any
              manticore_response = generate_manticore_response(webmock_response).call
              real_request = false

            elsif real_request_allowed?(request_signature.uri)
              manticore_response = Manticore::Response.new(client, request, context, &block).call
              webmock_response = generate_webmock_response(manticore_response)
              real_request = true

            else
              raise WebMock::NetConnectNotAllowedError.new(request_signature)
            end

            WebMock::CallbackRegistry.invoke_callbacks({:lib => :manticore, :real_request => real_request}, request_signature, webmock_response)
            manticore_response
          end

          def registered_response_for(request_signature)
            WebMock::StubRegistry.instance.response_for_request(request_signature)
          end

          def real_request_allowed?(uri)
            WebMock.net_connect_allowed?(uri)
          end

          def generate_webmock_request_signature
            WebMock::RequestSignature.new(@method, @uri, {:body => @options[:body], :headers => @options[:headers]})
          end

          def generate_manticore_response(webmock_response)
            raise Manticore::ConnectTimeout if webmock_response.should_timeout

            Manticore::StubbedResponse.stub(
              :code => webmock_response.status[0],
              :body => webmock_response.body,
              :headers => webmock_response.headers,
              :cookies => {}
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
