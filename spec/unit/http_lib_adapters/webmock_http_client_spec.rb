require 'spec_helper'

describe EventMachine::WebMockHttpClient do

  describe 'get_response_cookie' do

    before(:each) do
      stub_request(:get, "http://example.org/").
      to_return(
        status: 200,
        body: "",
        headers: { 'Set-Cookie' => cookie_string }
      )
    end

    describe 'success' do

      context 'with only one cookie' do

        let(:cookie_name) { 'name_of_the_cookie' }
        let(:cookie_value) { 'value_of_the_cookie' }
        let(:cookie_string) { "#{cookie_name}=#{cookie_value}" }

        it 'successfully gets the cookie' do
          EM.run {
            http = EventMachine::HttpRequest.new('http://example.org').get

            http.errback { fail(http.error) }
            http.callback {
              http.get_response_cookie(cookie_name).should == cookie_value
              EM.stop
            }
          }
        end
      end

      context 'with several cookies' do

        let(:cookie_name) { 'name_of_the_cookie' }
        let(:cookie_value) { 'value_of_the_cookie' }
        let(:cookie_2_name) { 'name_of_the_2nd_cookie' }
        let(:cookie_2_value) { 'value_of_the_2nd_cookie' }
        let(:cookie_string) { %W(#{cookie_name}=#{cookie_value} #{cookie_2_name}=#{cookie_2_value}) }

        it 'successfully gets both cookies' do
          EM.run {
            http = EventMachine::HttpRequest.new('http://example.org').get

            http.errback { fail(http.error) }
            http.callback {
              http.get_response_cookie(cookie_name).should == cookie_value
              http.get_response_cookie(cookie_2_name).should == cookie_2_value
              EM.stop
            }
          }
        end
      end
    end

    describe 'failure' do

      let(:cookie_string) { 'a=b' }

      it 'returns nil when no cookie is found' do
        EM.run {
            http = EventMachine::HttpRequest.new('http://example.org').get

            http.errback { fail(http.error) }
            http.callback {
              http.get_response_cookie('not_found_cookie').should == nil
              EM.stop
            }
          }
      end
    end
  end
end