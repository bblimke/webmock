require "spec_helper"
begin
  require "httparty"
rescue LoadError
  @skip_specs = true
end

unless @skip_specs
  RSpec.describe "Hash including Bug" do
    let!(:dummy_url) { 'http://dummyurl.com' }

    it "receive a request" do
      stub_request(:get, dummy_url).
        with(:query => hash_including({ :param1 => 5 })).
        to_return(:body => 'body 1')

      expect(
        HTTParty.get(dummy_url, {
          :query => {
            :param1 => 5,
            :param2 => 'random1'
          }
        }).body
      ).to eq 'body 1'
    end
  end
end
