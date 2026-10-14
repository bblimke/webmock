# frozen_string_literal: true

module WebMock
  class RackResponse < Response
    def initialize(app)
      @app = app
    end

    def evaluate(request)
      env = build_rack_env(request)

      status, headers, response = @app.call(env)

      Response.new(
        body: body_from_rack_response(response),
        headers: headers,
        status: [status, Rack::Utils::HTTP_STATUS_CODES[status]]
      )
    end

    def body_from_rack_response(response)
      body = "".dup
      response.each { |line| body << line }
      response.close if response.respond_to?(:close)
      return body
    end

    def build_rack_env(request)
      uri = request.uri
      headers = (request.headers || {}).dup
      body = (request.body || '').b
      content_type = headers.delete('Content-Type')
      content_length = headers.delete('Content-Length')

      env = {
        # CGI variables specified by Rack
        'REQUEST_METHOD'  => request.method.to_s.upcase,
        'PATH_INFO'       => uri.path,
        'QUERY_STRING'    => uri.query || '',
        'SERVER_NAME'     => uri.host,
        'SERVER_PORT'     => uri.port.to_s,
        'SERVER_PROTOCOL' => 'HTTP/1.1',
        'SCRIPT_NAME'     => ""
      }

      # Like a server, only set these when the request has them.
      env['CONTENT_TYPE'] = Array(content_type).join(', ') if content_type
      env['CONTENT_LENGTH'] = body.bytesize.to_s if content_length || !body.empty?

      env['HTTP_AUTHORIZATION'] = 'Basic ' + [uri.userinfo].pack('m').delete("\r\n") if uri.userinfo

      # Rack-specific variables
      env['rack.input']      = StringIO.new(body)
      env['rack.errors']     = $stderr
      if !Rack.const_defined?(:RELEASE) || Rack::RELEASE < "3"
        env['rack.version']      = Rack::VERSION
        env['rack.multithread']  = false
        env['rack.multiprocess'] = false
      end
      env['rack.url_scheme'] = uri.scheme
      env['rack.run_once']   = true

      # Servers join repeated headers into one value. Rack splits cookies on
      # "; ", so join them that way.
      headers.each do |k, v|
        env["HTTP_#{k.tr('-','_').upcase}"] = Array(v).join(k == 'Cookie' ? '; ' : ', ')
      end

      # Many clients add Host only when sending, so fill it in as they would.
      env['HTTP_HOST'] ||= uri.port == uri.default_port ? uri.host : "#{uri.host}:#{uri.port}"

      env
    end
  end
end
