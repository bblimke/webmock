# frozen_string_literal: true

require 'thread'

module WebMock
  module Util
    class HashCounter
      # The key the counter holds, its count, and when it was last put.
      Entry = Struct.new(:key, :count, :position)

      attr_accessor :hash

      def initialize
        self.hash = Hash.new(0)
        @entries = {}
        @max = 0
        @lock = ::Mutex.new
      end

      # Returns the key the counter holds: a copy of the first one put for an
      # equal key. The copy is also what the counter looks keys up by, so a
      # caller changing its key later cannot change the counts.
      def put(key, num=1)
        @lock.synchronize do
          entry = @entries[key]
          unless entry
            copy = key.dup
            entry = @entries[copy] = Entry.new(copy, 0, 0)
          end
          entry.count += num
          entry.position = @max += 1
          hash[entry.key] = entry.count
          entry.key
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
          @entries.values.sort_by(&:position).map { |entry| [entry.key, entry.count] }
        end
        entries.each { |key, count| yield(key, count) }
      end
    end
  end
end
