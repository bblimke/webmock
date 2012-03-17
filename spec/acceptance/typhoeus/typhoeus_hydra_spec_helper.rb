require 'ostruct'

module TyphoeusHydraSpecHelper
  class FakeTyphoeusHydraTimeoutError < StandardError; end
  class FakeTyphoeusHydraConnectError < StandardError; end


  def http_request(method, uri, options = {}, &block)
    uri.gsub!(" ", "%20") #typhoeus doesn't like spaces in the uri
    response = Typhoeus::Request.run(uri,
      {
        :method  => method,
        :body    => options[:body],
        :headers => options[:headers],
        :timeout => 25000, # milliseconds
        :verbose => true
      }
    )
    raise FakeTyphoeusHydraTimeoutError.new if response.timed_out?
    if response.code == 0
      p response
      raise FakeTyphoeusHydraConnectError.new
    end
    OpenStruct.new({
      :body => response.body,
      :headers => WebMock::Util::Headers.normalize_headers(join_array_values(response.headers_hash)),
      :status => response.code.to_s,
      :message => response.status_message
    })
  end

  def join_array_values(hash)
    joined = {}
    if hash
     hash.each do |k,v|
       v = v.join(", ") if v.is_a?(Array)
       joined[k] = v
     end
    end
    joined
  end


  def client_timeout_exception_class
    FakeTyphoeusHydraTimeoutError
  end

  def connection_refused_exception_class
    FakeTyphoeusHydraConnectError
  end

  def http_library
    :typhoeus
  end

end
