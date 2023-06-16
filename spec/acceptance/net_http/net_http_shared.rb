require 'set'

shared_examples_for "Net::HTTP" do
  describe "when making real requests", net_connect: true do
    let(:port){ WebMockServer.instance.port }

    before(:each) do
      @http = Net::HTTP.new("localhost", port)
    end

    it "should return a Net::ReadAdapter from response.body when a real request is made with a block and #read_body", net_connect: true do
      response = Net::HTTP.new("localhost", port).request_get('/') { |r| r.read_body { } }
      expect(response.body).to be_a(Net::ReadAdapter)
    end

    it "should handle requests with block passed to read_body", net_connect: true do
      body = "".dup
      req = Net::HTTP::Get.new("/")
      Net::HTTP.start("localhost", port) do |http|
        http.request(req) do |res|
          res.read_body do |str|
            body << str
          end
        end
      end
      expect(body).to match(/hello world/)
    end

    it "should connect only once when connected on start", net_connect: true do
      @http = Net::HTTP.new('localhost', port)
      socket_before_request = socket_after_request = nil
      @http.start {|conn|
        socket_before_request = conn.instance_variable_get(:@socket)
        conn.request(Net::HTTP::Get.new("/"))
        socket_after_request = conn.instance_variable_get(:@socket)
      }

      if !defined?(WebMock::NetHTTPUtility) || WebMock::Config.instance.net_http_connect_on_start
        expect(socket_before_request).to be_a(Net::BufferedIO)
        expect(socket_after_request).to be_a(Net::BufferedIO)
        expect(socket_after_request).to be(socket_before_request)
      else
        expect(socket_before_request).to be_a(StubSocket)
        expect(socket_after_request).to be_a(Net::BufferedIO)
      end
    end

    it "should allow sending multiple requests when persisted", net_connect: true do
      @http = Net::HTTP.new('example.org')
      @http.start
      expect(@http.get("/")).to be_a(Net::HTTPSuccess)
      expect(@http.get("/")).to be_a(Net::HTTPSuccess)
      expect(@http.get("/")).to be_a(Net::HTTPSuccess)
      @http.finish
    end

    it "should not leak file descriptors", net_connect: true do
      sockets = Set.new

      @http = Net::HTTP.new('example.org')
      @http.start
      sockets << @http.instance_variable_get(:@socket)
      @http.get("/")
      sockets << @http.instance_variable_get(:@socket)
      @http.get("/")
      sockets << @http.instance_variable_get(:@socket)
      @http.get("/")
      sockets << @http.instance_variable_get(:@socket)
      @http.finish

      if !defined?(WebMock::NetHTTPUtility) || WebMock.net_http_connect_on_start?(Addressable::URI.parse("http://example.com/"))
        expect(sockets.length).to eq(1)
        expect(sockets.to_a[0]).to be_a(Net::BufferedIO)
      else
        expect(sockets.length).to eq(2)
        expect(sockets.to_a[0]).to be_a(StubSocket)
        expect(sockets.to_a[1]).to be_a(Net::BufferedIO)
      end

      expect(sockets.all?(&:closed?)).to be(true)
    end

    it "should pass the read_timeout value on", net_connect: true do
      @http = Net::HTTP.new('localhost', port)
      read_timeout = @http.read_timeout + 1
      @http.read_timeout = read_timeout
      @http.start {|conn|
        conn.request(Net::HTTP::Get.new("/"))
        socket = conn.instance_variable_get(:@socket)
        expect(socket.read_timeout).to eq(read_timeout)
      }
    end

    describe "without start" do
      it "should close connection after a real request" do
        @http.get('/') { }
        expect(@http).not_to be_started
      end

      it "should execute block exactly once" do
        times = 0
        @http.get('/') { times += 1 }
        expect(times).to eq(1)
      end

      it "should have socket open during a real request" do
        socket_id = nil
        @http.get('/') {
          socket_id = @http.instance_variable_get(:@socket).object_id
        }
        expect(socket_id).not_to be_nil
      end

      it "should be started during a real request" do
        started = nil
        @http.get('/') {
          started = @http.started?
        }
        expect(started).to eq(true)
        expect(@http.started?).to eq(false)
      end
    end

    describe "with start" do
      it "should close connection after a real request" do
        @http.start {|conn| conn.get('/') { } }
        expect(@http).not_to be_started
      end

      it "should execute block exactly once" do
        times = 0
        @http.start {|conn| conn.get('/') { times += 1 }}
        expect(times).to eq(1)
      end

      it "should have socket open during a real request" do
        socket_id = nil
        @http.start {|conn| conn.get('/') {
            socket_id = conn.instance_variable_get(:@socket).object_id
          }
        }
        expect(socket_id).not_to be_nil
      end

      it "should be started during a real request" do
        started = nil
        @http.start {|conn| conn.get('/') {
            started = conn.started?
          }
        }
        expect(started).to eq(true)
        expect(@http.started?).to eq(false)
      end
    end

    describe "with start without request block" do
      it "should close connection after a real request" do
        @http.start {|conn| conn.get('/') }
        expect(@http).not_to be_started
      end

      it "should have socket open during a real request" do
        socket_id = nil
        @http.start {|conn|
          socket_id = conn.instance_variable_get(:@socket).object_id
        }
        expect(socket_id).not_to be_nil
      end

      it "should be started during a real request" do
        started = nil
        @http.start {|conn|
          started = conn.started?
        }
        expect(started).to eq(true)
        expect(@http.started?).to eq(false)
      end
    end

    describe "with start without a block and finish" do
      it "should gracefully start and close connection" do
        @http.start
        @http.get("/")
        expect(@http).to be_started
        @http.finish
        expect(@http).not_to be_started
      end
    end
  end
end
