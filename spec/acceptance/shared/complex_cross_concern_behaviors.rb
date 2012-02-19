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
end

