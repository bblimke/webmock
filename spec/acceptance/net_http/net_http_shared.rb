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
      socket_id_before_request = socket_id_after_request = nil
      @http.start {|conn|
        socket_id_before_request = conn.instance_variable_get(:@socket).object_id
        conn.request(Net::HTTP::Get.new("/"))
        socket_id_after_request = conn.instance_variable_get(:@socket).object_id
      }

      if !defined?(WebMock::Config) || WebMock::Config.instance.net_http_connect_on_start
        expect(socket_id_before_request).not_to eq(nil.object_id)
        expect(socket_id_after_request).not_to eq(nil.object_id)
        expect(socket_id_after_request).to eq(socket_id_before_request)
      else
        expect(socket_id_before_request).to eq(nil.object_id)
        expect(socket_id_after_request).not_to eq(nil.object_id)
      end
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
