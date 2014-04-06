require 'rack'

class MyRackApp
  class NonArrayResponse
    # The rack response body need not implement #join,
    # but it must implement #each.  It need not be an Array.
    # ActionDispatch::Response, for example, exercises that fact.
    # See: http://rack.rubyforge.org/doc/SPEC.html

    def each(*args, &blk)
      ["This is not in an array!"].each(*args, &blk)
    end
  end

  def self.call(env)
    case env.values_at('REQUEST_METHOD', 'PATH_INFO')
      when ['GET', '/']
        [200, {}, ["This is my root!"]]
      when ['GET', '/greet']
        name = env['QUERY_STRING'][/name=([^&]*)/, 1] || "World"
        [200, {}, ["Hello, #{name}"]]
      when ['GET', '/non_array_response']
        [200, {}, NonArrayResponse.new]
      when ['GET', '/locked']
        [200, {}, ["Single threaded response."]]
      when ['POST', '/greet']
        name = env["rack.input"].read(env["CONTENT_LENGTH"])
        name = name.force_encoding("UTF-8") if name.respond_to? :force_encoding
        name = name[/name=([^&]*)/, 1] || "World"
        [200, {}, ["Good to meet you, #{name}!"]]
      when ['GET', '/compute']
        if env['SERVER_PORT'] == 80 && env["SCRIPT_NAME"] == ""
          [200, {}, [""]]
        else
          [401, {}, [""]]
        end
      when ['GET', '/error']
        env['rack.errors'].puts('Error!')
        [500, {}, ['']]
      else
        [404, {}, ['']]
    end
  end
end

class MyLockedRackApp
  MUTEX = Mutex.new

  def self.call(env)
    lock = Rack::Lock.new(MyRackApp, MUTEX)
    lock.call(env)
  end
end
