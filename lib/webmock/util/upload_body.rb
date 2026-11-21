# frozen_string_literal: true

require 'stringio'

module WebMock
  module Util
    module UploadBody
      # Inspect a replayable upload through its own reader. A wrapper may
      # transform the bytes in the underlying file (for example, gzip).
      def self.read(stream, headers)
        source = stream.respond_to?(:to_io) ? stream.to_io : stream
        replayable = source.is_a?(StringIO) || (source.is_a?(IO) && source.stat.file?)
        return stream.to_s unless replayable && stream.respond_to?(:pos) &&
          (stream.respond_to?(:seek) || stream.respond_to?(:rewind))

        _, length = headers.find { |name, _| name.to_s.casecmp?('Content-Length') }
        return ''.b if length && length.to_i.zero?

        # IO#pos can discard bytes from ungetbyte. sysseek gives the file
        # offset only when Ruby has no buffered input. Otherwise restore
        # the bytes through the reader's buffer.
        if source.is_a?(IO) && stream.respond_to?(:sysseek) && stream.respond_to?(:ungetbyte)
          # Switch a read/write file to reading before asking for its offset.
          # Pending writes otherwise leave the descriptor behind the reader.
          stream.read(0)
          begin
            position = stream.sysseek(0, IO::SEEK_CUR)
          rescue IOError
            buffered = true
          end
        else
          position = stream.pos
        end
        body = ''.b
        each_chunk(stream, length&.to_i) { |chunk| body << chunk.b }
        body
      ensure
        if buffered && body && !body.empty?
          stream.ungetbyte(body)
        elsif position
          if stream.respond_to?(:seek)
            stream.seek(position)
          else
            stream.rewind
            each_chunk(stream, position) { }
          end
        end
      end

      def self.each_chunk(stream, length)
        while length.nil? || length > 0
          size = length ? [length, 64 * 1024].min : 64 * 1024
          chunk = stream.read(size)
          break if chunk.nil? || chunk.empty?
          yield chunk
          length -= chunk.bytesize if length
        end
      end
      private_class_method :each_chunk
    end
  end
end
