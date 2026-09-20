require 'spec_helper'
require 'acceptance/webmock_shared'
require_relative './async_http_client_spec_helper'

unless RUBY_PLATFORM =~ /java/
  require 'protocol/http/body/file'

  Async.logger.debug! if ENV['ASYNC_LOGGER_DEBUG']

  describe 'Async::HTTP::Client' do
    include AsyncHttpClientSpecHelper

    include_context "with WebMock",
      :no_status_message,
      :no_url_auth,
      :no_content_length_header

    it 'works' do
      stub_request(:get, 'http://www.example.com')
      expect(make_request(:get, 'http://www.example.com')).to eq(
        status: 200,
        headers: {},
        body: nil
      )
    end

    it 'works with request path' do
      stub_request(:get, 'http://www.example.com/foo')
      expect(make_request(:get, 'http://www.example.com/foo')).to eq(
        status: 200,
        headers: {},
        body: nil
      )
    end

    it 'works with request query' do
      stub_request(:get, 'http://www.example.com/').with(
        query: {
          'foo' => 'bar'
        }
      )
      expect(make_request(:get, 'http://www.example.com/?foo=bar')).to eq(
        status: 200,
        headers: {},
        body: nil
      )
    end

    it 'works with request headers' do
      stub_request(:get, 'http://www.example.com').with(
        headers: {
          'X-Token' => 'Token'
        }
      )
      expect(
        make_request :get, 'http://www.example.com',
          headers: {
            'X-Token' => 'Token'
        }
      ).to eq(
        status: 200,
        headers: {},
        body: nil
      )
    end

    def request_signature_for(headers)
      endpoint = Async::HTTP::Endpoint.parse('http://www.example.com')
      wrapper = Async::HTTP::WebMockClientWrapper.new(endpoint)
      request = Struct.new(:method, :scheme, :authority, :path, :headers, :body) do
        def read
          'body'
        end
      end.new('GET', 'http', 'www.example.com', '/', ::Protocol::HTTP::Headers.new(headers), nil)

      wrapper.send(:build_request_signature, request)
    end

    it 'does not raise when a request header has a nil value' do
      # "connection" has a policy in protocol-http, so a nil value used to
      # raise inside Headers#to_h (protocol-http >= 0.56.0).
      signature = request_signature_for([['x-token', 'abc'], ['connection', nil]])

      expect(signature.headers).to eq('X-Token' => 'abc')
    end

    it 'groups values of the same request header sent in different casings' do
      signature = request_signature_for([['X-Token', 'a'], ['x-token', 'b']])

      expect(signature.headers).to eq('X-Token' => ['a', 'b'])
    end

    it 'works with request body as text' do
      stub_request(:post, 'http://www.example.com').with(
        body: 'x'*10_000
      )
      expect(
        make_request :post, 'http://www.example.com',
          body: 'x'*10_000
      ).to eq(
        status: 200,
        headers: {},
        body: nil
      )
    end

    it 'works with request body as file' do
      stub_request(:post, "www.example.com").with(
        body: File.read(__FILE__)
      )
      expect(
        make_request :post, "http://www.example.com",
          body: ::Protocol::HTTP::Body::File.open(__FILE__, block_size: 32)
      ).to eq(
        status: 200,
        headers: {},
        body: nil
      )
    end

    it 'works with response status' do
      stub_request(:get, 'http://www.example.com').to_return(
        status: 400
      )
      expect(make_request(:get, 'http://www.example.com')).to eq(
        status: 400,
        headers: {},
        body: nil
      )
    end

    it 'works with response headers' do
      stub_request(:get, 'http://www.example.com').to_return(
        headers: {
          'X-Token' => 'TOKEN'
        }
      )
      expect(make_request(:get, 'http://www.example.com')).to eq(
        status: 200,
        headers: {
          'x-token' => ['TOKEN']
        },
        body: nil
      )
    end

    it 'works with response body' do
      stub_request(:get, 'http://www.example.com').to_return(
        body: 'abc'
      )
      expect(make_request(:get, 'http://www.example.com')).to eq(
        status: 200,
        headers: {},
        body: 'abc'
      )
    end

    it 'works with to_timeout' do
      stub_request(:get, 'http://www.example.com').to_timeout
      expect { make_request(:get, 'http://www.example.com') }.to raise_error Async::TimeoutError
    end

    it 'does not invoke "after real request" callbacks for stubbed requests' do
      WebMock.allow_net_connect!
      stub_request(:get, 'http://www.example.com').to_return(body: 'abc')

      callback_invoked = false
      WebMock.after_request(real_requests_only: true) { |_| callback_invoked = true }

      make_request(:get, 'http://www.example.com')
      expect(callback_invoked).to eq(false)
    end

    it 'does invoke "after request" callbacks for stubbed requests' do
      WebMock.allow_net_connect!
      stub_request(:get, 'http://www.example.com').to_return(body: 'abc')

      callback_invoked = false
      WebMock.after_request(real_requests_only: false) { |_| callback_invoked = true }

      make_request(:get, 'http://www.example.com')
      expect(callback_invoked).to eq(true)
    end

    context 'with a real response' do
      # build_webmock_response is the only place the adapter reads a status
      # description, and only real responses reach it.
      let(:server_url) { "http://#{WebMockServer.instance.host_with_port}/" }

      after do
        WebMock.reset_callbacks
        WebMock.disable_net_connect!
      end

      it 'builds a webmock response with a status message' do
        WebMock.allow_net_connect!

        recorded_response = nil
        WebMock.after_request { |_request, response| recorded_response = response }

        make_request(:get, server_url)

        expect(recorded_response.status).to eq([200, 'OK'])
      end
    end

    context 'scheme and protocol' do
      let(:default_response_headers) { {} }

      before do
        stub_request(
          :get, "#{scheme}://www.example.com"
        ).and_return(
          body: 'BODY'
        )
      end

      subject do
        make_request(:get, "#{scheme}://www.example.com", protocol: protocol)
      end

      shared_examples :common do
        specify do
          expect(subject).to eq(
            status: 200,
            headers: default_response_headers,
            body: 'BODY'
          )
        end
      end

      context 'http scheme' do
        let(:scheme) { 'http' }

        context 'default protocol' do
          let(:protocol) { nil }

          include_examples :common
        end

        context 'HTTP10 protocol' do
          let(:protocol) { Async::HTTP::Protocol::HTTP10 }
          let(:default_response_headers) { {"connection"=>["keep-alive"]} }

          include_examples :common
        end

        context 'HTTP11 protocol' do
          let(:protocol) { Async::HTTP::Protocol::HTTP11 }

          include_examples :common
        end

        context 'HTTP2 protocol' do
          let(:protocol) { Async::HTTP::Protocol::HTTP2 }

          include_examples :common
        end
      end

      context 'https scheme' do
        let(:scheme) { 'https' }

        context 'default protocol' do
          let(:protocol) { nil }

          include_examples :common
        end

        context 'HTTP10 protocol' do
          let(:protocol) { Async::HTTP::Protocol::HTTP10 }
          let(:default_response_headers) { {"connection"=>["keep-alive"]} }

          include_examples :common
        end

        context 'HTTP11 protocol' do
          let(:protocol) { Async::HTTP::Protocol::HTTP11 }

          include_examples :common
        end

        context 'HTTP2 protocol' do
          let(:protocol) { Async::HTTP::Protocol::HTTP2 }

          include_examples :common
        end

        context 'HTTPS protocol' do
          let(:protocol) { Async::HTTP::Protocol::HTTPS }

          include_examples :common
        end
      end
    end

    context 'multiple requests' do
      let!(:endpoint) { Async::HTTP::Endpoint.parse('http://www.example.com') }
      let(:requests_count) { 3 }

      shared_examples :common do
        before do
          requests_count.times do |index|
            stub_request(
              :get, "http://www.example.com/foo#{index}"
            ).to_return(
              status: 200 + index,
              headers: {'X-Token' => "foo#{index}"},
              body: "FOO#{index}"
            )
          end
        end

       specify do
         expect(subject).to eq(
           0 => {
             status: 200,
             headers: {'x-token' => ['foo0']},
             body: 'FOO0'
           },
           1 => {
             status: 201,
             headers: {'x-token' => ['foo1']},
             body: 'FOO1'
           },
           2 => {
             status: 202,
             headers: {'x-token' => ['foo2']},
             body: 'FOO2'
           }
         )
       end
      end

      context 'sequential' do
        subject do
          responses = {}
          Async do |task|
            Async::HTTP::Client.open(endpoint, protocol: protocol) do |client|
              requests_count.times do |index|
                response = client.get "/foo#{index}"
                responses[index] = response_to_hash(response)
              end
            end
          end
          responses
        end

        context 'HTTP1 protocol' do
          let!(:protocol) { Async::HTTP::Protocol::HTTP1 }

          include_examples :common
        end

        context 'HTTP2 protocol' do
          let!(:protocol) { Async::HTTP::Protocol::HTTP2 }

          include_examples :common
        end
      end

      context 'asynchronous' do
        subject do
          responses = {}
          Async do |task|
            Async::HTTP::Client.open(endpoint, protocol: protocol) do |client|
              tasks = requests_count.times.map do |index|
                task.async do
                  response = client.get "/foo#{index}"
                  responses[index] = response_to_hash(response)
                end
              end

              tasks.map(&:wait)
            end
          end
          responses
        end

        context 'HTTP1 protocol' do
          let!(:protocol) { Async::HTTP::Protocol::HTTP1 }

          include_examples :common
        end

        context 'HTTP2 protocol' do
          let!(:protocol) { Async::HTTP::Protocol::HTTP2 }

          include_examples :common
        end
      end
    end

    def make_request(method, url, protocol: nil, headers: {}, body: nil)
      result  = Async do
        endpoint = Async::HTTP::Endpoint.parse(url)

        begin
          Async::HTTP::Client.open(endpoint, protocol: protocol || endpoint.protocol) do |client|
            response = client.send(
              method,
              endpoint.path,
              headers,
              body
            )
            response_to_hash(response)
          end
        rescue Async::TimeoutError => e
          e
        end
      end.wait

      result.is_a?(Exception) ? raise(result) : result
    end

    def response_to_hash(response)
      {
        status: response.status,
        headers: response.headers.to_h,
        body: response.read
      }
    end
  end
end
