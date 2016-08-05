# encoding: utf-8
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
