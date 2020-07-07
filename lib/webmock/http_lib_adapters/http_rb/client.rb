module HTTP
  class Client
    alias_method :__perform__, :perform

    def perform(request, options)
      return __perform__(request, options) unless webmock_enabled?
       
      response = options.features.inject(response) do |response, (_name, feature)|
        feature.wrap_response(response)
      end
      response
    end

    def webmock_enabled?
      ::WebMock::HttpLibAdapters::HttpRbAdapter.enabled?
    end
  end
end
