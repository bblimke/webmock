# frozen_string_literal: true

# This code is entierly copied from VCR (http://github.com/myronmarston/vcr) by courtesy of Myron Marston

# A Net::HTTP response that has already been read raises an IOError when #read_body
# is called with a destination string or block.
#
# This causes a problem when VCR records a response--it reads the body before yielding
# the response, and if the code that is consuming the HTTP requests uses #read_body, it
# can cause an error.
#
# This is a bit of a hack, but it allows a Net::HTTP response to be "re-read"
# after it has aleady been read.  This attemps to preserve the behavior of
# #read_body, acting just as if it had never been read.


module Net
  module WebMockHTTPResponse
    def read_body(dest = nil, &block)
      if !(defined?(@__read_body_previously_called).nil?) && @__read_body_previously_called
        return super
      end
      if dest.nil? && block.nil?
        apply_body_encoding
        return @body
      end
      raise ArgumentError.new("both arg and block given for HTTP method") if dest && block
      return nil if @body.nil?

      dest ||= ::Net::ReadAdapter.new(block)
      dest << @body.dup
      @body = dest
    ensure
      # allow subsequent calls to #read_body to proceed as normal, without our hack...
      @__read_body_previously_called = true
    end

    private

    # Net::HTTPResponse#read_body applies the encoding set with #body_encoding=
    # (or Net::HTTP#response_body_encoding=) to the body it reads, so do the
    # same for a body that was set without reading it.
    def apply_body_encoding
      encoding = defined?(@body_encoding) && @body_encoding
      return unless encoding && @body.is_a?(String)

      encoding = detect_encoding(@body) unless encoding.is_a?(Encoding)
      @body = @body.dup.force_encoding(encoding) if encoding
    end
  end
end

