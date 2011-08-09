require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "WebMock version" do
  it "should report version" do
    WebMock.version.should == WebMock::VERSION
  end
end