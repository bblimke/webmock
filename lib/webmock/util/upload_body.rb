# frozen_string_literal: true

require 'stringio'

module WebMock
  module Util
    module UploadBody
      def self.read(stream, headers)
        # Only inspect readers whose buffering and pushback semantics we know.
        # A wrapper can delegate ungetbyte to a file while transforming read.
        read_owner = stream.method(:read).owner
        if defined?(Tempfile) && stream.is_a?(Tempfile) && read_owner == Tempfile.instance_method(:read).owner
          stream = stream.to_io
          read_owner = stream.method(:read).owner
        end
        gzip = defined?(Zlib::GzipReader) && read_owner == Zlib::GzipReader
        source = gzip ? stream.to_io : stream
        return stream.to_s unless (read_owner == IO || read_owner == StringIO || gzip) &&
          (source.is_a?(StringIO) || (source.is_a?(IO) && source.stat.file?))

        _, length = headers.find { |name, _| name.to_s.casecmp?('Content-Length') }
        return ''.b if length && length.to_i.zero?

        if gzip
          # Rewinding a gzip reader loses its pushed-back, uncompressed bytes.
          # GzipReader#ungetc accepts the whole string, including binary data.
          pushback = :ungetc
        elsif source.is_a?(IO)
          # Flush pending writes before checking the descriptor offset.
          # sysseek rejects buffered input, which IO#pos would discard.
          stream.read(0)
          begin
            position = stream.sysseek(0, IO::SEEK_CUR)
          rescue IOError
            pushback = :ungetbyte
          end
        else
          position = stream.pos
        end
        body = ''.b
        each_chunk(stream, length&.to_i) { |chunk| body << chunk.b }
        body
      ensure
        if pushback && body && !body.empty?
          stream.public_send(pushback, body)
        elsif position
          stream.seek(position)
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
