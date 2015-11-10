require 'thread'

module WebMock
  module Util
    class Util::HashCounter
      attr_accessor :hash
      def initialize
        self.hash = {}
        @order = {}
        @max = 0
        @lock = ::Mutex.new
      end
      def put key, num=1
        @lock.synchronize do
          val = hash[key]
          hash[key] = (val || 0) + num
          @max += 1
          @order[key] = @max
        end
      end
      def get key
        @lock.synchronize do
          hash[key] || 0
        end
      end

      def each(&block)
        @order.to_a.sort {|a, b| a[1] <=> b[1]}.each do |a|
          block.call(a[0], hash[a[0]])
        end
      end
    end
  end
end
