begin
  require 'excon'
rescue LoadError
  # excon not found
end

if defined?(Excon)
  WebMock::VersionChecker.new('Excon', Excon::VERSION, '0.9.6').check_version!

  module WebMock
    module HttpLibAdapters

      class ExconAdapter < HttpLibAdapter
        adapter_for :excon

        def self.enable!
          Excon.send(:remove_const, :Connection)
          Excon.send(:const_set, :Connection, ExconConnection)
        end

        def self.disable!
          Excon.send(:remove_const, :Connection)
          Excon.send(:const_set, :Connection, ExconConnection.superclass)
        end


        def self.to_query(hash)
          string = ""
          for key, values in hash
            if values.nil?
              string << key.to_s << '&'
            else
              for value in [*values]
                string << key.to_s << '=' << CGI.escape(value.to_s) << '&'
              end
            end
          end
          string.chop! # remove trailing '&'
        end

        def self.build_request(params)
          params = params.dup
          method  = (params.delete(:method) || :get).to_s.downcase.to_sym
          params[:query] = to_query(params[:query]) if params[:query].is_a?(Hash)
          uri = Addressable::URI.new(params).to_s
          WebMock::RequestSignature.new method, uri, :body => body_from(params), :headers => params[:headers]
        end

        def self.body_from(params)
          body = params[:body]
          return body unless body.respond_to?(:read)

          contents = body.read
          body.rewind if body.respond_to?(:rewind)
          contents
        end

        def self.real_response(mock)
          raise Excon::Errors::Timeout if mock.should_timeout
          mock.raise_error_if_any
          Excon::Response.new \
            :body    => mock.body,
            :status  => mock.status[0].to_i,
            :headers => mock.headers
        end

        def self.mock_response(real, response_body_from_chunks)
          mock = WebMock::Response.new
          mock.status  = real.status
          mock.headers = real.headers
          mock.body    = response_body_from_chunks || real.body
          mock
        end

        def self.perform_callbacks(request, response, options = {})
          return unless WebMock::CallbackRegistry.any_callbacks?
          WebMock::CallbackRegistry.invoke_callbacks(options.merge(:lib => :excon), request, response)
        end

      end

      class ExconConnection < ::Excon::Connection

        def request_kernel(params)
          mock_request  = ExconAdapter.build_request params.dup
          WebMock::RequestRegistry.instance.requested_signatures.put(mock_request)

          if mock_response = WebMock::StubRegistry.instance.response_for_request(mock_request)
            ExconAdapter.perform_callbacks(mock_request, mock_response, :real_request => false)
            response = ExconAdapter.real_response(mock_response)

            if params.has_key?(:expects) && ![*params[:expects]].include?(response.status)
              raise(Excon::Errors.status_error(params, response))
            elsif params.has_key?(:response_block)
              content_length = remaining = response.body.bytesize
              body = response.body
              response.body = ""
              i = 0
              while i < body.length
                params[:response_block].call(body[i, params[:chunk_size]], [remaining - params[:chunk_size], 0].max, content_length)
                remaining -= params[:chunk_size]
                i += params[:chunk_size]
              end
            end
            response

          elsif WebMock.net_connect_allowed?(mock_request.uri)
            response_body_from_chunks = nil
            if params.has_key?(:response_block)
              response_body_from_chunks = ""
              original_block = params[:response_block]
              params[:response_block] = lambda {|chunk, remaining, total|
                response_body_from_chunks << chunk
                original_block.call(chunk, remaining, total)
              }
            end
            real_response = super
            ExconAdapter.perform_callbacks(mock_request, ExconAdapter.mock_response(real_response, response_body_from_chunks), :real_request => true)
            real_response
          else
            raise WebMock::NetConnectNotAllowedError.new(mock_request)
          end
        end

      end
    end
  end

end
