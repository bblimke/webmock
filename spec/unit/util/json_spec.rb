require 'spec_helper'

describe WebMock::Util::JSON do
  it "should parse json without parsing dates" do
    WebMock::Util::JSON.parse("\"a\":\"2011-01-01\"").should == {"a" => "2011-01-01"}
  end

  it "should parse json that includes binary strings" do
    WebMock::Util::JSON.parse("{\"a\":\"\\u0000\\u0001\\u0002\"}").should == {"a" => "\x00\x01\x02"}
  end
end
