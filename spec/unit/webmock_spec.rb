require 'spec_helper'

describe "WebMock" do

  describe ".version" do
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
  end

  describe ".net_connect_allowed?" do
    context 'enabled globally' do
      before do
        WebMock.enable_net_connect!
      end

      context 'without arguments' do
        it 'returns WebMock::Config.instance.allow_net_connect' do
          expect(WebMock.net_connect_allowed?).to eql(true)
        end
      end
    end

    context 'disabled with allowed remote string' do
      before do
        WebMock.disable_net_connect!(allow: "http://192.168.64.2:20031")
      end

      context 'without arguments' do
        it 'returns WebMock::Config.instance.allow_net_connect' do
          expect(WebMock.net_connect_allowed?).to eql(false)
        end
      end
    end

    context 'disabled with an allow list' do
      after do
        WebMock.disable_net_connect!
      end

      [
        # Host and host:port
        ["example.com", "http://example.com:8080/foo", true],
        ["example.com:8080", "http://example.com:8080/foo", true],
        ["example.com:8080", "http://example.com/foo", false],
        # A URL without a path allows every path on that scheme, host and port
        ["http://example.com", "http://example.com/", true],
        ["http://example.com", "http://example.com/foobar?a=1", true],
        ["http://example.com:80", "http://example.com/foo", true],
        ["http://example.com:8080", "http://example.com:8080/foo", true],
        ["https://example.com", "https://example.com/health", true],
        ["http://example.com", "http://example.com:8080/foo", false],
        ["https://example.com", "http://example.com/foo", false],
        # A trailing slash restricts requests to the root path and query
        ["http://example.com/", "http://example.com/", true],
        ["http://example.com/", "http://example.com", true],
        ["http://example.com/", "http://example.com/foobar", false],
        ["http://example.com/", "http://example.com/?x=1", false],
        ["https://example.com/", "https://example.com/", true],
        ["https://example.com/", "https://example.com/health", false],
        ["https://example.com:443/", "https://example.com/", true],
        ["https://example.com:443/", "https://example.com/health", false],
        ["http://example.com:8080/", "http://example.com:8080/", true],
        ["http://example.com:8080/", "http://example.com:8080/foo", false],
        ["http://example.com/foo/..", "http://example.com/foo", false],
        ["http://example.com?x=1", "http://example.com/?x=1", true],
        ["http://example.com?x=1", "http://example.com/foo?x=1", false],
        # A URL with a path allows that path and query, compared like stubs
        ["https://github.com/mozilla/geckodriver/releases/latest", "https://github.com/mozilla/geckodriver/releases/latest", true],
        ["https://github.com:443/mozilla/geckodriver/releases/latest", "https://github.com/mozilla/geckodriver/releases/latest", true],
        ["http://Example.com/foo", "http://example.com/foo", true],
        ["HTTP://Example.com/foo", "http://example.com/foo", true],
        ["http://example.com/foo?b=2&a=1", "http://example.com/foo?a=1&b=2", true],
        ["http://example.com/search?q=a+b", "http://example.com/search?q=a+b", true],
        ["http://example.com/s?ids[]=1&ids[]=2", "http://example.com/s?ids[]=1&ids[]=2", true],
        ["http://example.com/foo", "http://example.com/foo/bar", false],
        ["http://example.com/foo", "http://other.example.com/foo", false],
        ["http://example.com/foo", "http://example.com:8080/foo", false],
        ["http://example.com/foo", "http://example.com/foo?x=1", false],
        ["http://example.com/foo?x=1", "http://example.com/foo", false],
        ["http://example.com/?x=1", "http://example.com/foo?x=1", false],
        # Credentials are ignored, as for hosts
        ["https://api.example.com/v1/x", "https://user:pw@api.example.com/v1/x", true],
        ["https://user:pw@api.example.com/v1/x", "https://api.example.com/v1/x", true],
        # Strings that are not valid URLs never match
        ["http://[bad", "http://example.com/", false],
        # A Regexp matches the URL with its port, and without it on the default port
        [%r{\Ahttps://example\.com/foo\z}, "https://example.com/foo", true],
        [%r{\Ahttps://example\.com:443/foo\z}, "https://example.com/foo", true],
        [%r{\Ahttps://example\.com/foo\z}, "https://example.com:8443/foo", false],
        [%r{example\.com:8443}, "https://example.com:8443/foo", true]
      ].each do |allowed, request_uri, expected|
        it "#{expected ? 'allows' : 'does not allow'} #{request_uri} when #{allowed.inspect} is allowed" do
          WebMock.disable_net_connect!(allow: allowed)
          expect(WebMock.net_connect_allowed?(request_uri)).to eq(expected)
        end
      end

      it "matches an Addressable URI without an explicit default port" do
        WebMock.disable_net_connect!(allow: "http://example.com/foo")
        uri = Addressable::URI.parse("http://example.com/foo")

        expect(WebMock.net_connect_allowed?(uri)).to be true
      end

      it "normalizes the host and query of an Addressable URI" do
        WebMock.disable_net_connect!(allow: "http://example.com/foo?a=1&b=2")
        uri = Addressable::URI.parse("http://EXAMPLE.com:80/foo?b=2&a=1")

        expect(WebMock.net_connect_allowed?(uri)).to be true
      end

      it "strips the default port before a query for a Regexp, for a URI without a path" do
        WebMock.disable_net_connect!(allow: %r{\Ahttp://example\.com\?x=1\z})
        expect(WebMock.net_connect_allowed?(Addressable::URI.parse("http://example.com:80?x=1"))).to be true
      end

      it "does not strip a port from a query value when matching a Regexp" do
        WebMock.disable_net_connect!(allow: %r{other\.com/})
        uri = Addressable::URI.parse("http://example.com:80?callback=http://other.com:80/")

        expect(WebMock.net_connect_allowed?(uri)).to be false
      end
    end

    context 'disabled globally' do
      before do
        WebMock.disable_net_connect!
      end

      context 'without arguments' do
        it 'returns WebMock::Config.instance.allow_net_connect' do
          expect(WebMock.net_connect_allowed?).to eql(false)
        end
      end
    end
  end

  describe ".net_http_connect_on_start?" do
    let(:uri) { Addressable::URI.parse("http://example.org:5432") }

    it "will not connect on start when false" do
      WebMock.disable_net_connect!
      expect(WebMock.net_http_connect_on_start?(uri)).to be(false)
    end

    it "will connect on start when true" do
      WebMock.disable_net_connect!(net_http_connect_on_start: true)
      expect(WebMock.net_http_connect_on_start?(uri)).to be(true)
    end

    it "will connect on start when regexp matches" do
      WebMock.disable_net_connect!(net_http_connect_on_start: /example/)
      expect(WebMock.net_http_connect_on_start?(uri)).to be(true)
    end

    it "will not connect on start when regexp does not match" do
      WebMock.disable_net_connect!(net_http_connect_on_start: /nope/)
      expect(WebMock.net_http_connect_on_start?(uri)).to be(false)
    end

    it "will connect on start when host matches" do
      WebMock.disable_net_connect!(net_http_connect_on_start: "example.org")
      expect(WebMock.net_http_connect_on_start?(uri)).to be(true)
    end

    it "will not connect on start when host does not match" do
      WebMock.disable_net_connect!(net_http_connect_on_start: "localhost")
      expect(WebMock.net_http_connect_on_start?(uri)).to be(false)
    end

    it "will connect on start when host + port matches" do
      WebMock.disable_net_connect!(net_http_connect_on_start: "example.org:5432")
      expect(WebMock.net_http_connect_on_start?(uri)).to be(true)
    end

    it "will not connect on start when host + port does not match" do
      WebMock.disable_net_connect!(net_http_connect_on_start: "example.org:80")
      expect(WebMock.net_http_connect_on_start?(uri)).to be(false)
    end

    it "will connect on start when scheme + host + port matches" do
      WebMock.disable_net_connect!(net_http_connect_on_start: "http://example.org:5432")
      expect(WebMock.net_http_connect_on_start?(uri)).to be(true)
    end

    it "normalizes the host of a connection URI when matching an allowed URL" do
      WebMock.disable_net_connect!(net_http_connect_on_start: "http://EXAMPLE.org")
      uri = Addressable::URI.parse("http://EXAMPLE.org:80")

      expect(WebMock.net_http_connect_on_start?(uri)).to be true
    end

    it "does not connect on start when the allowed URL requires a path" do
      WebMock.disable_net_connect!(net_http_connect_on_start: "http://example.org:5432/health")

      expect(WebMock.net_http_connect_on_start?(uri)).to be false
    end

    it "does not connect on start when the allowed URL requires the root path" do
      WebMock.disable_net_connect!(net_http_connect_on_start: "http://example.org:5432/")

      expect(WebMock.net_http_connect_on_start?(uri)).to be false
    end

    it "will not connect on start when scheme + host + port does not match" do
      WebMock.disable_net_connect!(net_http_connect_on_start: "https://example.org:5432")
      expect(WebMock.net_http_connect_on_start?(uri)).to be(false)
    end
  end
end
