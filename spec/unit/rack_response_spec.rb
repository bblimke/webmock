require 'spec_helper'

describe WebMock::RackResponse do
  before :each do
    @rack_response = WebMock::RackResponse.new(MyRackApp)
  end

  it "should hook up to a rack appliance" do
    request = WebMock::RequestSignature.new(:get, 'www.example.com')
    response = @rack_response.evaluate(request)

    expect(response.status.first).to eq(200)
    expect(response.body).to include('This is my root!')
  end

  it "should set the reason phrase based on the status code" do
    request = WebMock::RequestSignature.new(:get, 'www.example.com')
    response = @rack_response.evaluate(request)
    expect(response.status).to eq([200, "OK"])

    request = WebMock::RequestSignature.new(:get, 'www.example.com/error')
    response = @rack_response.evaluate(request)
    expect(response.status).to eq([500, "Internal Server Error"])
  end

  it "should behave correctly when the rack response is not a simple array of strings" do
    request = WebMock::RequestSignature.new(:get, 'www.example.com/non_array_response')
    response = @rack_response.evaluate(request)

    expect(response.status.first).to eq(200)
    expect(response.body).to include('This is not in an array!')
  end

  it "should shouldn't blow up when hitting a locked resource twice" do
    @locked_rack_response = WebMock::RackResponse.new(MyLockedRackApp)
    request = WebMock::RequestSignature.new(:get, 'www.example.com/locked')
    @locked_rack_response.evaluate(request)
    response2 = @locked_rack_response.evaluate(request)

    expect(response2.body).to include('Single threaded response.')
    expect(response2.status.first).to eq(200)
  end

  it "should send along params" do
    request = WebMock::RequestSignature.new(:get, 'www.example.com/greet?name=Johnny')

    response = @rack_response.evaluate(request)

    expect(response.status.first).to eq(200)
    expect(response.body).to include('Hello, Johnny')
  end

  it "should send along POST params" do
    request = WebMock::RequestSignature.new(:post, 'www.example.com/greet',
      body: 'name=Jimmy'
    )

    response = @rack_response.evaluate(request)
    expect(response.body).to include('Good to meet you, Jimmy!')
  end

  it "should send params with proper content length if params have non-ascii symbols" do
    request = WebMock::RequestSignature.new(:post, 'www.example.com/greet',
      body: 'name=Олег'
    )

    response = @rack_response.evaluate(request)
    expect(response.body).to include('Good to meet you, Олег!')
  end

  it "should send or not a rack.version depending on the Rack version" do
    request = WebMock::RequestSignature.new(:get, 'www.example.com/env')
    response = @rack_response.evaluate(request)

    expect(response.status.first).to eq(200)
    body = JSON.parse(response.body)

    if Gem.loaded_specs["rack"].version > Gem::Version.new("3.0.0")
      expect(body).not_to include("rack.version")
    else
      expect(body).to include("rack.version")
    end
  end

  describe "env" do
    def env_for(method, url, options = {})
      env = nil
      app = lambda { |rack_env| env = rack_env; [200, {"content-type" => "text/plain"}, ["ok"]] }
      WebMock::RackResponse.new(app).evaluate(WebMock::RequestSignature.new(method, url, options))
      env
    end

    [
      [:get, "http://www.example.com/", {}],
      [:post, "http://www.example.com/", {body: '{"a":1}', headers: {"Content-Type" => "application/json", "Content-Length" => "7"}}],
      [:get, "https://user:pass@www.example.com/", {headers: {"Accept" => ["text/html", "application/json"], "Cookie" => ["a=1", "b=2"]}}],
      [:post, "http://[::1]:8080/", {body: "caf\u00e9"}]
    ].each do |method, url, options|
      it "passes Rack::Lint for #{method.upcase} #{url} with #{options}" do
        lint_app = Rack::Lint.new(lambda { |_| [200, {"content-type" => "text/plain"}, ["ok"]] })
        request = WebMock::RequestSignature.new(method, url, options)
        expect(WebMock::RackResponse.new(lint_app).evaluate(request).body).to eq("ok")
      end
    end

    it "has the port, body length and protocol as strings, like a server" do
      env = env_for(:post, "http://www.example.com/", body: "caf\u00e9")
      expect(env.values_at('SERVER_PORT', 'CONTENT_LENGTH', 'SERVER_PROTOCOL')).to eq(["80", "5", "HTTP/1.1"])
    end

    it "leaves out CONTENT_TYPE and CONTENT_LENGTH for a request without a body or those headers" do
      expect(env_for(:get, "http://www.example.com/").keys).not_to include('CONTENT_TYPE', 'CONTENT_LENGTH')
    end

    it "gives a Content-Length header as CONTENT_LENGTH only" do
      env = env_for(:post, "http://www.example.com/", body: "abc", headers: {"Content-Length" => "3"})
      expect(env['CONTENT_LENGTH']).to eq("3")
      expect(env).not_to include('HTTP_CONTENT_LENGTH')
    end

    it "joins repeated header values, and cookies with a semicolon" do
      env = env_for(:get, "http://www.example.com/", headers: {"Accept" => ["text/html", "application/json"], "Cookie" => ["a=1", "b=2"]})
      expect(env['HTTP_ACCEPT']).to eq("application/json, text/html")
      expect(env['HTTP_COOKIE']).to eq("a=1; b=2")
    end

    it "gives the body as binary" do
      input = env_for(:post, "http://www.example.com/", body: "caf\u00e9")['rack.input']
      expect(input.read).to eq("caf\u00e9".b)
    end
  end

  describe "HTTP_HOST" do
    def rack_env_for(request)
      JSON.parse(@rack_response.evaluate(request).body)
    end

    {
      'http://www.example.com/env' => 'www.example.com',
      'https://www.example.com/env' => 'www.example.com',
      'http://www.example.com:8080/env' => 'www.example.com:8080',
      'https://www.example.com:80/env' => 'www.example.com:80',
      'http://[::1]:8080/env' => '[::1]:8080',
      'http://user:pass@www.example.com/env' => 'www.example.com'
    }.each do |url, host|
      it "is #{host} for a request to #{url} without a Host header" do
        request = WebMock::RequestSignature.new(:get, url)
        expect(rack_env_for(request)['HTTP_HOST']).to eq(host)
      end
    end

    it "is not added to the request headers" do
      request = WebMock::RequestSignature.new(:get, 'http://www.example.com/env')
      rack_env_for(request)
      expect(request.headers).to be_nil
    end

    it "is the Host header when the request has one" do
      request = WebMock::RequestSignature.new(:get, 'http://www.example.com:8080/env', headers: {'Host' => 'other.example.com'})
      expect(rack_env_for(request)['HTTP_HOST']).to eq('other.example.com')
    end
  end

  it "shouldn't set a rack.session" do
    request = WebMock::RequestSignature.new(:get, 'www.example.com/env')
    response = @rack_response.evaluate(request)

    expect(response.status.first).to eq(200)
    body = JSON.parse(response.body)

    expect(body).not_to include("rack.session")
    expect(body).not_to include("rack.session.options")
  end

  describe 'rack error output' do
    before :each do
      @original_stderr = $stderr
      $stderr = StringIO.new
    end

    after :each do
      $stderr = @original_stderr
    end

    it 'should behave correctly when an app uses rack.errors' do
      request = WebMock::RequestSignature.new(:get, 'www.example.com/error')

      expect { @rack_response.evaluate(request) }.to_not raise_error
      expect($stderr.length).to_not eq 0
    end
  end

  describe 'basic auth request' do
    before :each do
      @rack_response_with_basic_auth = WebMock::RackResponse.new(
        Rack::Auth::Basic.new(MyRackApp) do |username, password|
          username == 'username' && password == 'password'
        end
      )
    end
    it 'should be failure when wrong credentials' do
      request = WebMock::RequestSignature.new(:get, 'foo:bar@www.example.com')
      response = @rack_response_with_basic_auth.evaluate(request)
      expect(response.status.first).to eq(401)
      expect(response.body).not_to include('This is my root!')
    end

    it 'should be success when valid credentials' do
      request = WebMock::RequestSignature.new(:get, 'username:password@www.example.com')
      response = @rack_response_with_basic_auth.evaluate(request)
      expect(response.status.first).to eq(200)
      expect(response.body).to include('This is my root!')
    end
  end
end
