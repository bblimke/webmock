shared_examples_for "precedence of stubs" do
  it "should use the last declared matching request stub" do
    stub_http_request(:get, "www.example.com").to_return(:body => "abc")
    stub_http_request(:get, "www.example.com").to_return(:body => "def")
    http_request(:get, "http://www.example.com/").body.should == "def"
  end

  it "should not be affected by the type of uri or request method" do
    stub_http_request(:get, "www.example.com").to_return(:body => "abc")
    stub_http_request(:any, /.*example.*/).to_return(:body => "def")
    http_request(:get, "http://www.example.com/").body.should == "def"
  end
end
