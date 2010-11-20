require 'ostruct'

module TyphoeusHydraSpecHelper
  class FakeTyphoeusError < StandardError; end
  
  
  def http_request(method, uri, options = {}, &block)
    uri.gsub!(" ", "%20") #typhoeus doesn't like spaces in the uri
    response = Typhoeus::Request.run(uri,
      {
        :method  => method,
        :body    => options[:body],
        :headers => options[:headers],
        :timeout => 2000 # milliseconds
      }
    )
    raise FakeTyphoeusError.new if response.code.to_s == "0"
    OpenStruct.new({
      :body => response.body,
      :headers => WebMock::Util::Headers.normalize_headers(join_array_values(response.headers_hash)),
      :status => response.code.to_s,
      :message => response.status_message
    })
  end

  def client_timeout_exception_class
    FakeTyphoeusError
  end

  def connection_refused_exception_class
    FakeTyphoeusError
  end

  def setup_expectations_for_real_request(options = {})
    #TODO
  end

  def http_library
    :typhoeus
  end

  private
  
  def join_array_values(headers)
    joined = {}
    if headers
      headers.each do |k,v|
        v = v.join(", ") if v.is_a?(Array)
        joined[k] = v 
      end
    end
    joined
  end

end
