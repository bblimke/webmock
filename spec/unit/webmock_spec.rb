require 'spec_helper'

describe "WebMock version" do
  it "should report version" do
    expect(WebMock.version).to eq(WebMock::VERSION)
  end

  it "should not require safe_yaml" do
    expect(defined?SafeYAML).to eq(nil)
  end
end

describe "Enabling" do
  it "should reflect when it is enabled" do
    WebMock.enable!
    expect(WebMock.enabled?).to eq true
  end
end

describe "Disabling" do
  it "should reflect when it is enabled" do
    WebMock.enable!
    WebMock.disable!
    expect(WebMock.enabled?).to eq false
  end
end

