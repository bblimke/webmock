# frozen_string_literal: true

require 'thread'

module WebMock
  module Util
    class HashCounter
      attr_accessor :hash

      def initialize
        self.hash = Hash.new(0)
        @order = {}
        @keys = {}
        @max = 0
        @lock = ::Mutex.new
      end

      # Returns the key the counter holds: a copy of the first one put for an
      # equal key, so a caller changing its key later cannot change the counts.
      def put(key, num=1)
        @lock.synchronize do
          key = @keys[key] ||= key.dup
          hash[key] += num
          @order[key] = @max += 1
          key
        end
      end

      def get(key)
        @lock.synchronize do
          hash[key]
        end
      end

      # The block runs on a snapshot, outside the lock, so it can make
      # requests or call WebMock without deadlocking.
      def select(&block)
        return unless block_given?

        @lock.synchronize { hash.dup }.select(&block)
      end

      # Like select, it yields from a snapshot, outside the lock.
      def each(&block)
        entries = @lock.synchronize do
          @order.sort_by { |_, position| position }.map { |key, _| [key, hash[key]] }
        end
        entries.each { |key, count| yield(key, count) }
      end
    end
  end
end
