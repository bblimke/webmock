require 'spec_helper'

describe WebMock::RackResponse do
  before :each do
    @rack_response = WebMock::RackResponse.new(MyRackApp)
    @locked_rack_response = WebMock::RackResponse.new(MyLockedRackApp)
    @rack_response_with_basic_auth = WebMock::RackResponse.new(
      Rack::Auth::Basic.new(MyRackApp) do |username, password|
        username == 'username' && password == 'password'
      end
    )
  end

  it "should hook up to a rack appliance" do
    request = WebMock::RequestSignature.new(:get, 'www.example.com')
    response = @rack_response.evaluate(request)

    response.status.first.should == 200
    response.body.should include('This is my root!')
  end

  it "should behave correctly when the rack response is not a simple array of strings" do
    request = WebMock::RequestSignature.new(:get, 'www.example.com/non_array_response')
    response = @rack_response.evaluate(request)

    response.status.first.should == 200
    response.body.should include('This is not in an array!')
  end

  it "should shouldn't blow up when hitting a locked resource twice" do
    request   = WebMock::RequestSignature.new(:get, 'www.example.com/locked')
    response  = @locked_rack_response.evaluate(request)
    response2 = @locked_rack_response.evaluate(request)

    response2.body.should include('Single threaded response.')
    response2.status.first.should == 200
  end

  it "should send along params" do
    request = WebMock::RequestSignature.new(:get, 'www.example.com/greet?name=Johnny')

    response = @rack_response.evaluate(request)

    response.status.first.should == 200
    response.body.should include('Hello, Johnny')
  end

  it "should send along POST params" do
    request = WebMock::RequestSignature.new(:post, 'www.example.com/greet',
      :body => 'name=Jimmy'
    )

    response = @rack_response.evaluate(request)
    response.body.should include('Good to meet you, Jimmy!')
  end

  describe 'basic auth request' do
    it 'should be failure when wrong credentials' do
      request = WebMock::RequestSignature.new(:get, 'foo:bar@www.example.com')
      response = @rack_response_with_basic_auth.evaluate(request)
      response.status.first.should == 401
      response.body.should_not include('This is my root!')
    end

    it 'should be success when valid credentials' do
      request = WebMock::RequestSignature.new(:get, 'username:password@www.example.com')
      response = @rack_response_with_basic_auth.evaluate(request)
      response.status.first.should == 200
      response.body.should include('This is my root!')
    end
  end
end
