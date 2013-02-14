shared_context "complex cross-concern behaviors" do |*adapter_info|
  it 'allows a response with multiple values for the same header to be recorded and played back exactly as-is' do
    WebMock.allow_net_connect!

    recorded_response = nil
    WebMock.after_request { |_,r| recorded_response = r }
    real_response = http_request(:get, webmock_server_url)

    stub_request(:get, webmock_server_url).to_return(
      :status => recorded_response.status,
      :body => recorded_response.body,
      :headers => recorded_response.headers
    )

    played_back_response = http_request(:get, webmock_server_url)

    played_back_response.headers.keys.should include('Set-Cookie')
    played_back_response.should == real_response
  end

  let(:no_content_url) { 'http://httpstat.us/204' }
  [nil, ''].each do |stub_val|
    it "returns the same value (nil or "") for a request stubbed as #{stub_val.inspect} that a real empty response has", :net_connect => true do
      unless http_library == :curb
        WebMock.allow_net_connect!

        real_response = http_request(:get, no_content_url)
        stub_request(:get, no_content_url).to_return(:status => 204, :body => stub_val)
        stubbed_response = http_request(:get, no_content_url)

        stubbed_response.body.should eq(real_response.body)
      end
    end
  end
end

