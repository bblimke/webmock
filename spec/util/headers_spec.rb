require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe WebMock::Util::Headers do

  it "should decode_userinfo_from_header handles basic auth" do
    authorization_header = "Basic dXNlcm5hbWU6c2VjcmV0"
    userinfo = Util::Headers.decode_userinfo_from_header(authorization_header)
    userinfo.should == "username:secret"
  end

end
