module HTTP
  class Client
    alias_method :__perform__, :perform

    def perform(request, options)
      return __perform__(request, options) unless webmock_enabled?
      WebMockPerform.new(request) { __perform__(request, options) }.exec
    end

    def webmock_enabled?
      ::WebMock::HttpLibAdapters::HttpRbAdapter.enabled?
    end
  end
end
