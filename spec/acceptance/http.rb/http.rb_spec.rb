# The http.rb gem and the http gem both define HTTP, and both have a lib/http.rb, so
# these examples run in a process of their own (rake spec_http_dot_rb) with the http
# gem off the load path, as it is where only http.rb is installed.
return unless Gem.loaded_specs['http.rb']
if defined?(HTTP) || !RSpec.configuration.files_to_run.all?{|path| path.start_with?(__dir__)}
  warn "The http.rb examples run on their own: rake spec_http_dot_rb"
  return
end
if Gem.loaded_specs['http']
  $LOAD_PATH.reject!{|path| Gem.loaded_specs['http'].full_require_paths.include?(path)}
end
require "http"

require "spec_helper"

describe "http.rb" do
  it "is not taken for the http gem" do
    expect(WebMock::HttpLibAdapterRegistry.instance.http_lib_adapters).not_to have_key(:http_rb)
  end

  context "with credentials" do
    it "matches credentials in the URL as basic auth" do
      stub_request(:get, "http://www.example.com/").with(basic_auth: ['user', 'pass']).to_return(body: "abc")
      expect(HTTP.get("http://user:pass@www.example.com/").body).to eq("abc")
    end

    it "matches the username and password options as basic auth" do
      stub_request(:get, "http://www.example.com/").with(basic_auth: ['user', 'pass']).to_return(body: "abc")
      expect(HTTP.get("http://www.example.com/", {}, {}, {username: 'user', password: 'pass'}).body).to eq("abc")
    end
  end

  context "with query arguments" do
    it "matches them as the query" do
      stub_request(:get, "http://www.example.com/").with(query: {a: '1', b: 'c d'}).to_return(body: "abc")
      expect(HTTP.get("http://www.example.com/", {a: 1, b: 'c d'}).body).to eq("abc")
    end
  end

  context "with JSON data" do
    it "matches the JSON body" do
      stub_request(:post, "http://www.example.com/").with(body: {a: 1}, headers: {'Content-Type' => 'application/json'})
      expect(HTTP.post("http://www.example.com/", {a: 1}, {'Content-Type' => 'application/json'}).code).to eq("200")
    end
  end

  context "with form data" do
    it "matches the form body" do
      stub_request(:post, "http://www.example.com/").with(body: {a: '1', b: '2'})
      expect(HTTP.post("http://www.example.com/", {a: 1, b: 2}).code).to eq("200")
    end
  end

  context "following redirects" do
    before do
      stub_request(:get, "http://www.example.com/from").to_return(status: 302, headers: {'Location' => '/to'})
      stub_request(:get, "http://www.example.com/to").to_return(body: "abc")
    end

    it "requests each stubbed location in turn" do
      response = HTTP.get("http://www.example.com/from")
      expect(response.body).to eq("abc")
      expect(response.uri.to_s).to eq("http://www.example.com/to")
    end

    it "stops at the first response with no_redirect" do
      expect(HTTP.get("http://www.example.com/from", {}, {}, {no_redirect: true}).code).to eq("302")
      expect(a_request(:get, "http://www.example.com/to")).not_to have_been_made
    end
  end

  context "with retries" do
    before do
      allow(HTTP::RETRY).to receive(:sleep)
    end

    it "takes the next declared response for each attempt" do
      stub_request(:get, "http://www.example.com/").to_return({status: 503}, {body: "abc"})
      expect(HTTP.get("http://www.example.com/", {}, {}, {retries: 1}).body).to eq("abc")
      expect(a_request(:get, "http://www.example.com/")).to have_been_made.twice
    end

    it "retries a stubbed timeout" do
      stub_request(:get, "http://www.example.com/").to_timeout.then.to_return(body: "abc")
      expect(HTTP.get("http://www.example.com/", {}, {}, {retries: 1}).body).to eq("abc")
    end
  end
end
