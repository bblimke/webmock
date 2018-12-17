require 'spec_helper'

describe "WebMock version" do
  it "should report version" do
    expect(WebMock.version).to eq(WebMock::VERSION)
  end

  it "should not require safe_yaml" do
    expect(defined?SafeYAML).to eq(nil)
  end

  it "should alias enable_net_connect! to allow_net_connect!" do
    expect(WebMock.enable_net_connect!).to eq(WebMock.allow_net_connect!)
  end

  it "should alias disallow_net_connect! to disable_net_connect!" do
    expect(WebMock.disallow_net_connect!).to eq(WebMock.disallow_net_connect!)
  end
end
