require 'spec_helper'

unless RUBY_PLATFORM =~ /java/
  describe 'Curb::Multi' do
    include LocalHTTPServer

    before do
      WebMock.disable_net_connect!
      @multi = Curl::Multi.new
    end

    after do
      @multi.close
      WebMock::CallbackRegistry.reset
    end

    it 'answers individual handles from stubs during perform and records each once' do
      stub = stub_request(:get, 'http://example.com/').to_return(body: 'stubbed')
      easy = Curl::Easy.new('http://example.com/')
      completed = []
      easy.on_complete do |handle|
        expect(handle.multi).to equal(@multi)
        completed << handle.body_str
      end

      expect(@multi.add(easy)).to equal(@multi)
      @multi.add(easy)
      expect(completed).to be_empty
      expect(@multi.requests.values).to eq([easy])
      expect(@multi).not_to be_idle
      expect(@multi.perform).to eq(true)
      expect(completed).to eq(['stubbed'])
      expect(@multi).to be_idle
      @multi.perform
      expect(completed).to eq(['stubbed'])
      expect(stub).to have_been_requested.once
    end

    it 'rejects an unstubbed handle before it can enter the native loop' do
      server = TCPServer.new('127.0.0.1', 0)
      easy = Curl::Easy.new("http://127.0.0.1:#{server.addr[1]}/blocked")
      expect { @multi.add(easy) }.to raise_error(WebMock::NetConnectNotAllowedError)
      expect(@multi).to be_idle
      expect(server.accept_nonblock(exception: false)).to eq(:wait_readable)
    ensure
      server&.close
    end

    it 'mixes stubs and native transfers with curb and WebMock callbacks' do
      callbacks, real_callbacks, complete, success = [], [], [], []
      WebMock.after_request { |request, response| callbacks << [request.uri.path, response.body] }
      WebMock.after_request(real_requests_only: true) { |request, response| real_callbacks << [request.uri.path, response.body] }
      response = "HTTP/1.1 200 OK\r\nContent-Length: 4\r\nConnection: close\r\n\r\nreal"
      heads = capture_requests(1, response: response) do |port|
        WebMock.disable_net_connect!(allow_localhost: true)
        stub_request(:get, "http://127.0.0.1:#{port}/stub").to_return(body: 'stub')
        %w[stub real].each do |path|
          easy = Curl::Easy.new("http://127.0.0.1:#{port}/#{path}")
          # Any implementation serializing these via Easy#perform is incorrect.
          expect(easy).not_to receive(:perform)
          easy.on_complete { |handle| complete << [path, handle.body_str] }
          easy.on_success { |handle| success << [path, handle.response_code] }
          @multi.add(easy)
        end
        @multi.perform
      end
      expect(heads.map(&:first)).to contain_exactly(a_string_starting_with('GET /real '))
      expect(complete).to contain_exactly(['stub', 'stub'], ['real', 'real'])
      expect(success).to contain_exactly(['stub', 200], ['real', 200])
      expect(callbacks).to contain_exactly(['/stub', 'stub'], ['/real', 'real'])
      expect(real_callbacks).to eq([['/real', 'real']])
      expect(WebMock).to have_requested(:get, %r{/stub$}).once
      expect(WebMock).to have_requested(:get, %r{/real$}).once
    end

    it 'keeps concurrent real transfers on the same native multi loop' do
      server = TCPServer.new('127.0.0.1', 0)
      thread = Thread.new do
        clients = []
        begin
          # Neither response is sent until BOTH requests have arrived. A serial
          # Easy#perform implementation times out instead of passing this test.
          2.times do
            raise 'real transfers were serialized' unless IO.select([server], nil, nil, 5)
            client = server.accept
            clients << client
            while (line = client.gets) && line != "\r\n"
            end
          end
          clients.each { |client| client.write(LocalHTTPServer::EMPTY_RESPONSE) }
        ensure
          clients.each(&:close)
        end
      end
      thread.report_on_exception = false
      WebMock.disable_net_connect!(allow_localhost: true)
      stub_request(:get, 'http://example.com/stub')
      completed = []
      ['http://example.com/stub', *2.times.map { |i| "http://127.0.0.1:#{server.addr[1]}/#{i}" }].each do |url|
        easy = Curl::Easy.new(url)
        easy.timeout = 8
        easy.on_complete { |handle| completed << handle.response_code }
        @multi.add(easy)
      end
      @multi.perform
      thread.value
      expect(completed).to eq([200, 200, 200])
    ensure
      thread&.kill
      server&.close
    end

    it 'uses the configured methods, bodies and headers for each handle' do
      [[:post, 'post_body=', 'form=data'], [:put, 'put_data=', 'upload'], [:head, 'head=', true], [:delete, 'delete=', true]].each do |method, setter, value|
        stub = stub_request(method, "http://example.com/#{method}").with(headers: {'X-Test' => 'yes'})
        stub.with(body: value) if [:post, :put].include?(method)
        stub.to_return(body: method.to_s)
        easy = Curl::Easy.new("http://example.com/#{method}")
        easy.public_send(setter, value)
        easy.headers['X-Test'] = 'yes'
        @multi.add(easy)
        @multi.perform
        expect(easy.body_str).to eq(method.to_s)
        expect(stub).to have_been_requested.once
      end
    end

    it 'supports Multi.get with more requests than the handle pool' do
      urls = 5.times.map { |i| "http://example.com/#{i}" }
      urls.each { |url| stub_request(:get, url).to_return(body: url) }
      bodies = []
      Curl::Multi.get(urls.dup, {}, max_connects: 2) { |easy| bodies << easy.body_str }
      expect(bodies).to match_array(urls)
      urls.each { |url| expect(WebMock).to have_requested(:get, url).once }
    end

    it 'supports the Curl.get convenience API without recording twice' do
      stub = stub_request(:get, 'http://example.com/').to_return(body: 'hello')
      expect(Curl.get('http://example.com/').body_str).to eq('hello')
      expect(stub).to have_been_requested.once
    end

    it 'allows removing, cancelling and closing queued stubs without callbacks' do
      stub_request(:get, 'http://example.com/')
      easy = Curl::Easy.new('http://example.com/')
      expect(easy).not_to receive(:invoke_curb_callbacks)
      @multi.add(easy)
      @multi.remove(easy)
      @multi.perform
      @multi.add(easy)
      @multi.cancel!
      @multi.perform
      @multi.add(easy)
      @multi.close
      expect(@multi).to be_idle
    end

    it 'can enqueue another stub from a completion callback' do
      first = stub_request(:get, 'http://example.com/first')
      second = stub_request(:get, 'http://example.com/second')
      completed = []
      easy = Curl::Easy.new('http://example.com/first')
      easy.on_complete do |handle|
        completed << handle.url
        if completed.length == 1
          handle.url = 'http://example.com/second'
          @multi.add(handle)
        end
      end
      @multi.add(easy)
      @multi.perform
      expect(completed).to eq(['http://example.com/first', 'http://example.com/second'])
      expect(first).to have_been_requested.once
      expect(second).to have_been_requested.once
    end

    it 'can enqueue stubs from a real completion callback and from the idle block' do
      stub_request(:get, 'http://example.com/from-complete')
      stub_request(:get, 'http://example.com/from-idle')
      completed = []
      capture_requests do |port|
        easy = Curl::Easy.new("http://127.0.0.1:#{port}/")
        easy.on_complete do
          stubbed = Curl::Easy.new('http://example.com/from-complete')
          stubbed.on_complete { completed << :complete }
          @multi.add(stubbed)
        end
        @multi.add(easy)
        added = false
        @multi.perform do
          unless added
            added = true
            stubbed = Curl::Easy.new('http://example.com/from-idle')
            stubbed.on_complete { completed << :idle }
            @multi.add(stubbed)
          end
        end
      end
      expect(completed).to contain_exactly(:complete, :idle)
      expect(@multi).to be_idle
    end

    it 'clears cached stub responses when reusing a handle for a real transfer' do
      capture_requests do |port|
        url = "http://127.0.0.1:#{port}/"
        stub = stub_request(:get, url).to_return(status: 201, body: 'old')
        easy = Curl::Easy.new(url)
        @multi.add(easy)
        @multi.perform
        expect(easy.body_str).to eq('old')
        remove_request_stub(stub)
        @multi.add(easy)
        @multi.perform
        expect(easy.body_str).to eq('')
        expect(easy.response_code).to eq(200)
        expect(easy.last_result).to eq(0)
      end
    end

    it 'invokes header, body, completion and status callbacks for stubs' do
      stub_request(:get, 'http://example.com/').to_return(status: 404, headers: {'X-Test' => 'yes'}, body: 'missing')
      easy = Curl::Easy.new('http://example.com/')
      events = []
      easy.on_header { |line| events << [:header, line]; line.bytesize }
      easy.on_body { |body| events << [:body, body]; body.bytesize }
      easy.on_complete { events << [:complete] }
      easy.on_missing { |handle, error| events << [:missing, handle.response_code, error] }
      @multi.add(easy)
      @multi.perform
      expect(events).to include([:header, "X-Test: yes"], [:body, 'missing'])
      expect(events.last(2)).to eq([[:complete], [:missing, 404, Curl::Easy.error(0)]])
    end

    it 'reports a stubbed timeout through the multi failure callback' do
      stub_request(:get, 'http://example.com/').to_timeout
      easy = Curl::Easy.new('http://example.com/')
      events = []
      easy.on_complete { |handle| events << [:complete, handle.last_result] }
      easy.on_failure { |handle, error| events << [:failure, error] }
      @multi.add(easy)
      expect { @multi.perform }.not_to raise_error
      expect(events).to eq([[:complete, 28], [:failure, Curl::Easy.error(28)]])
      expect(@multi).to be_idle
    end

    it 'records real response data without replacing streaming callbacks' do
      response = "HTTP/1.1 200 OK\r\nX-Test: yes\r\nContent-Length: 4\r\nConnection: close\r\n\r\nreal"
      recorded, body, headers = [], +"", +""
      WebMock.after_request { |_, result| recorded << result }
      capture_requests(1, response: response) do |port|
        easy = Curl::Easy.new("http://127.0.0.1:#{port}/")
        easy.on_body { |data| body << data; data.bytesize }
        easy.on_header { |data| headers << data; data.bytesize }
        @multi.add(easy)
        @multi.perform
      end
      expect(body).to eq('real')
      expect(headers).to include("X-Test: yes\r\n")
      expect(recorded.size).to eq(1)
      expect(recorded.first.body).to eq('real')
      expect(recorded.first.headers['X-Test']).to eq('yes')
    end

    it 'preserves native failure callbacks alongside successful stubs' do
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      server.close
      WebMock.disable_net_connect!(allow_localhost: true)
      stub_request(:get, 'http://example.com/').to_return(body: 'ok')
      easy = Curl::Easy.new("http://127.0.0.1:#{port}/")
      events = []
      easy.on_complete { |handle| events << [:complete, handle.last_result] }
      easy.on_failure { |handle, error| events << [:failure, error] }
      @multi.add(easy)
      stubbed = Curl::Easy.new('http://example.com/')
      @multi.add(stubbed)
      @multi.perform
      expect(events).to eq([[:complete, 7], [:failure, Curl::Easy.error(7)]])
      expect(stubbed.body_str).to eq('ok')
      expect(@multi).to be_idle
    end

    it 'does not double-record an Easy request using its internal multi handle' do
      callbacks = []
      WebMock.after_request { |request, _| callbacks << request }
      capture_requests do |port|
        url = "http://127.0.0.1:#{port}/"
        Curl::Easy.new(url).perform
        expect(WebMock).to have_requested(:get, url).once
      end
      expect(callbacks.length).to eq(1)
    end

    it 'can replace or clear callbacks after a real handle is added' do
      completed, recorded = [], []
      WebMock.after_request { |request, _| recorded << request }
      capture_requests do |port|
        easy = Curl::Easy.new("http://127.0.0.1:#{port}/")
        easy.on_complete { completed << :old }
        @multi.add(easy)
        easy.on_complete { completed << :new }
        easy.on_body { |data| data.bytesize }
        easy.on_body
        @multi.perform
      end
      expect(completed).to eq([:new])
      expect(recorded.size).to eq(1)
    end

    it 'does not replay a completed stub when its callback raises' do
      stub_request(:get, 'http://example.com/')
      easy = Curl::Easy.new('http://example.com/')
      easy.on_complete { raise 'callback failed' }
      @multi.add(easy)
      expect { @multi.perform }.to raise_error('callback failed')
      expect(@multi).to be_idle
      expect { @multi.perform }.not_to raise_error
    end

    it 'follows a stubbed redirect using the same native multi for the allowed destination' do
      callbacks, completed = [], []
      WebMock.after_request { |request, response| callbacks << [request.uri.path, response.status[0]] }
      capture_requests do |port|
        url = "http://127.0.0.1:#{port}/redirect"
        stub_request(:get, url).to_return(status: 302, headers: {'Location' => '/real'})
        easy = Curl::Easy.new(url)
        easy.follow_location = true
        expect(easy).not_to receive(:perform)
        easy.on_complete { |handle| completed << [handle.url, handle.last_effective_url, handle.response_code] }
        @multi.add(easy)
        @multi.perform
        expect(completed).to eq([[url, "http://127.0.0.1:#{port}/real", 200]])
      end
      expect(callbacks).to eq([['/redirect', 302], ['/real', 200]])
    end

    it 'limits stubbed redirect loops and invokes the failure callback once' do
      stub_request(:get, 'http://example.com/loop').to_return(status: 302, headers: {'Location' => '/loop'})
      easy = Curl::Easy.new('http://example.com/loop')
      easy.follow_location = true
      easy.max_redirects = 2
      failures = []
      easy.on_failure { |_, error| failures << error }
      @multi.add(easy)
      @multi.perform
      expect(failures).to eq([Curl::Easy.error(47)])
      expect(WebMock).to have_requested(:get, 'http://example.com/loop').times(3)
    end

    it "lets handles of curb's own Curl::Easy class make their requests, as before" do
      original_class = WebMock::HttpLibAdapters::CurbAdapter::OriginalCurlEasy
      # As if defined before WebMock was loaded.
      subclass = Class.new(original_class)
      codes = nil
      capture_request_heads(4) do |port|
        url = "http://127.0.0.1:#{port}/"
        # A handle made while WebMock was disabled, one of the subclass and
        # a copy, which curb makes of its own class.
        handles = [original_class.new(url), subclass.new(url), Curl::Easy.new(url).dup]
        handles.each(&:perform)
        added = subclass.new(url)
        @multi.add(added)
        @multi.perform
        codes = [*handles, added].map(&:response_code)
      end
      expect(codes).to eq([200, 200, 200, 200])
    end

    it 'does not run callbacks set before reset when a reset handle makes a real request' do
      completed = []
      url = nil
      capture_requests(2) do |port|
        url = "http://127.0.0.1:#{port}/"
        easy = Curl::Easy.new(url)
        easy.on_complete { completed << :before_reset }
        @multi.add(easy)
        @multi.perform
        easy.reset
        easy.url = url
        @multi.add(easy)
        @multi.perform
      end
      expect(completed).to eq([:before_reset])
      expect(WebMock).to have_requested(:get, url).twice
    end

    it 'restores the original multi class when the curb adapter is disabled' do
      WebMock.disable!(except: [:net_http])
      expect(Curl::Multi).to eq(WebMock::HttpLibAdapters::CurbAdapter::OriginalCurlMulti)
      WebMock.enable!
      expect(Curl::Multi).to eq(Curl::WebMockCurlMulti)
    ensure
      WebMock.enable!
    end
  end
end
