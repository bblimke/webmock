module WebMock
  module Matchers
    def have_been_made
      WebMock::RequestProfileMatcher.new
    end
    
    def have_not_been_made
      WebMock::RequestProfileMatcher.new.times(0)
    end
    
    def have_requested(method, url)
      WebMock::WebMockMatcher.new(method, url)
    end
    
    def have_not_requested(method, url)
      WebMock::WebMockMatcher.new(method, url).times(0)
    end
  end
end