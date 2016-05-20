shared_context "enabled and disabled webmock" do |*adapter_info|
  describe "when webmock is disabled" do
    before(:each) do
      WebMock.disable!
    end
    after(:each) do
      WebMock.enable!
    end
    include_context "disabled WebMock"
  end

  describe "when webmock is enabled again" do
    before(:each) do
      WebMock.disable!
      WebMock.enable!
    end
    include_context "enabled WebMock"
  end

  describe "when webmock is disabled except this lib" do
    before(:each) do
      WebMock.disable!(except: [http_library])
    end
    after(:each) do
      WebMock.enable!
    end
    include_context "enabled WebMock"
  end

  describe "when webmock is enabled except this lib" do
    before(:each) do
      WebMock.disable!
      WebMock.enable!(except: [http_library])
    end
    after(:each) do
      WebMock.enable!
    end
    include_context "disabled WebMock"
  end
end

shared_context "disabled WebMock" do
  it "should not register executed requests" do
    http_request(:get, webmock_server_url)
    expect(a_request(:get, webmock_server_url)).not_to have_been_made
  end

  it "should not block unstubbed requests" do
    expect {
      http_request(:get, webmock_server_url)
    }.not_to raise_error
  end

  it "should return real response even if there are stubs" do
    stub_request(:get, /.*/).to_return(body: "x")
    expect(http_request(:get, webmock_server_url).body).to eq("hello world")
  end

  it "should not invoke any callbacks" do
    WebMock.reset_callbacks
    stub_request(:get, webmock_server_url)
    @called = nil
    WebMock.after_request { @called = 1 }
    http_request(:get, webmock_server_url)
    expect(@called).to eq(nil)
  end
end

shared_context "enabled WebMock" do
  it "should register executed requests" do
    WebMock.allow_net_connect!
    http_request(:get, webmock_server_url)
    expect(a_request(:get, webmock_server_url)).to have_been_made
  end

  it "should block unstubbed requests" do
    expect {
      http_request(:get, "http://www.example.com/")
    }.to raise_error(WebMock::NetConnectNotAllowedError)
  end

  it "should return stubbed response" do
    stub_request(:get, /.*/).to_return(body: "x")
    expect(http_request(:get, "http://www.example.com/").body).to eq("x")
  end

  it "should invoke callbacks" do
    WebMock.allow_net_connect!
    WebMock.reset_callbacks
    @called = nil
    WebMock.after_request { @called = 1 }
    http_request(:get, webmock_server_url)
    expect(@called).to eq(1)
  end
end
