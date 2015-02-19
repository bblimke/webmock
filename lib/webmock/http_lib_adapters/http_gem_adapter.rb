begin
  require "http"
rescue LoadError
  # HTTP gem not found
end

if defined?(HTTP) && defined?(HTTP::VERSION)
  WebMock::VersionChecker.new("HTTP Gem", HTTP::VERSION, "0.6.0").check_version!

  module WebMock
    module HttpLibAdapters
      class HttpGemAdapter < HttpLibAdapter
        adapter_for :http_gem

        class << self
          def enable!
            @enabled = true
          end

          def disable!
            @enabled = false
          end

          def enabled?
            @enabled
          end
        end
      end
    end
  end

  require "webmock/http_lib_adapters/http_gem/client"
  require "webmock/http_lib_adapters/http_gem/request"
  require "webmock/http_lib_adapters/http_gem/response"
  require "webmock/http_lib_adapters/http_gem/streamer"
  require "webmock/http_lib_adapters/http_gem/webmock"
end
