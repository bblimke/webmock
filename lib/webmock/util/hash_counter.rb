module WebMock

  module Util

    class Util::HashCounter
      attr_accessor :hash
      def initialize
        self.hash = {}
      end
      def put key, num=1
        hash[key] = (hash[key] || 0) + num
      end
      def get key
        hash[key] || 0
      end
    end

  end
  
end
