# frozen_string_literal: true

require 'thread'

module WebMock
  module Util
    class HashCounter
      attr_accessor :hash, :array

      def initialize
        self.hash = Hash.new(0)
        @order = {}
        @max = 0
        @lock = ::Mutex.new
        self.array = []
        @request_object_ids = {}
      end

      def put(key, num=1)
        @lock.synchronize do
          store_to_array(key:, num:)
          hash[key] += num
          @order[key] = @max += 1
        end
      end

      def store_to_array(key:, num:)
        request_object_id = @request_object_ids[key.hash]
        request_object_id = key.object_id if request_object_id.nil?
        num.times do
          array << ObjectSpace._id2ref(request_object_id)
        end
        @request_object_ids[key.hash] = key.object_id
      end

      def get(key)
        @lock.synchronize do
          hash[key]
        end
      end

      def select(&block)
        return unless block_given?

        @lock.synchronize do
          hash.select(&block)
        end
      end

      def each(&block)
        @order.to_a.sort_by { |a| a[1] }.each do |a|
          yield(a[0], hash[a[0]])
        end
      end
    end
  end
end
