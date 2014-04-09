require 'webmock'

module Bacon
  class Context
    alias_method :after_webmock, :after
    def after(&block)
      after_webmock do
        block.call()
        WebMock.reset!
      end
    end
  end
end

