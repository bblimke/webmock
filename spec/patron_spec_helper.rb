module PatronSpecHelper
  def http_request(method, uri, options = {}, &block)
    uri = Addressable::URI.heuristic_parse(uri)
    sess = Patron::Session.new
    sess.base_url = "#{uri.omit(:userinfo, :query).normalize.to_s}".gsub(/\/$/,"")
    
    sess.username = uri.user
    sess.password = uri.password
    
    sess.timeout = 10
    
    response = sess.request(method, "#{uri.path}#{uri.query ? '?' : ''}#{uri.query}", options[:headers] || {}, {
      :data => options[:body]
    })
            
    OpenStruct.new({
      :body => response.body,
      :headers => WebMock::Util::Headers.normalize_headers(response.headers),
      :status => response.status.to_s })
  end
  
  def default_client_request_headers(request_method = nil, has_body = false)
    nil
  end

  def setup_expectations_for_real_request(options = {})
    #TODO
  end  

end
