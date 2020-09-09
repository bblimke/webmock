require 'spec_helper'

describe "WebMock version" do
  it "should report version" do
    expect(WebMock.version).to eq(WebMock::VERSION)
  end

  it "should not require safe_yaml" do
    expect(defined?SafeYAML).to eq(nil)
  end

  it "should alias enable_net_connect! to allow_net_connect!" do
    expect(WebMock.method(:enable_net_connect!)).to eq(WebMock.method(:allow_net_connect!))
  end

  it "should alias disallow_net_connect! to disable_net_connect!" do
    expect(WebMock.method(:disallow_net_connect!)).to eq(WebMock.method(:disable_net_connect!))
  end

  describe ".disable_net_connect!(options)" do
    it "always sets the allowed as an array" do
      WebMock.disable_net_connect!(allow: "allowed.net")

      expect(WebMock::Config.instance.allow).to eql ["allowed.net"]
    end

    it "always sets the allowed as a flat array" do
      WebMock.disable_net_connect!(allow: ["allowed.net"])

      expect(WebMock::Config.instance.allow).to eql ["allowed.net"]
    end
  end

  describe ".append_allowed!(*allowed)" do
    it "appends to previously set allowed host" do
      WebMock.disable_net_connect!(allow: ["allowed.net"])

      WebMock.append_allowed!("also-allowed.com")

      expect(WebMock::Config.instance.allow).to match_array ["allowed.net", "also-allowed.com"]
    end
  end

  describe ".clear_allowed!" do
    it "clears the previously set allowed hosts" do
      WebMock.disable_net_connect!(allow: ["allowed.net"])
      WebMock.append_allowed!("also-allowed.com")

      WebMock.clear_allowed!

      expect(WebMock::Config.instance.allow).to eql []
    end
  end
end
