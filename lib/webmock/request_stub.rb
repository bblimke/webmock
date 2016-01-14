module WebMock
  class RequestStub

    attr_accessor :request_pattern

    def initialize(method, uri)
      @request_pattern = RequestPattern.new(method, uri)
      @responses_sequences = []
      self
    end

    def with(params = {}, &block)
      @request_pattern.with(params, &block)
      self
    end

    def to_return(*response_hashes, &block)
      if block
        @responses_sequences << ResponsesSequence.new([ResponseFactory.response_for(block)])
      else
        @responses_sequences << ResponsesSequence.new([*response_hashes].flatten.map {|r| ResponseFactory.response_for(r)})
      end
      self
    end
    alias_method :and_return, :to_return

    def to_rack(app, options={})
      @responses_sequences << ResponsesSequence.new([RackResponse.new(app)])
    end

    def to_raise(*exceptions)
      @responses_sequences << ResponsesSequence.new([*exceptions].flatten.map {|e|
        ResponseFactory.response_for(:exception => e)
      })
      self
    end
    alias_method :and_raise, :to_raise

    def to_timeout
      @responses_sequences << ResponsesSequence.new([ResponseFactory.response_for(:should_timeout => true)])
      self
    end
    alias_method :and_timeout, :to_timeout

    def response
      if @responses_sequences.empty?
        WebMock::Response.new
      elsif @responses_sequences.length > 1
        @responses_sequences.shift if @responses_sequences.first.end?
        @responses_sequences.first.next_response
      else
        @responses_sequences[0].next_response
      end
    end

    # Fetch all requests from `WebMock::RequestRegistry` which match this stubs `@request_pattern`
    # @return [Array] the requested `WebMock::RequestSignature`s which match this stubs `@request_pattern`
    def requests
      request_registry = WebMock::RequestRegistry.instance
      signatures = request_registry.requested_signatures.ary
      return signatures.select { |signature|
        @request_pattern.matches?(signature)
      }
    end

    # Fetch the first request made for this stub
    # @return [WebMock::RequestSignature|nil] the first request signature for this stub, or nil if none were made
    def first_request
      return requests[0]
    end

    # Fetch the last request made for this stub
    # @return [WebMock::RequestSignature|nil] the last request signature for this stub, or nil if none were made
    def last_request
      return requests[-1]
    end

    def has_responses?
      !@responses_sequences.empty?
    end

    def then
      self
    end

    def times(number)
      raise "times(N) accepts integers >= 1 only" if !number.is_a?(Fixnum) || number < 1
      if @responses_sequences.empty?
        raise "Invalid WebMock stub declaration." +
          " times(N) can be declared only after response declaration."
      end
      @responses_sequences.last.times_to_repeat += number-1
      self
    end

    def matches?(request_signature)
      self.request_pattern.matches?(request_signature)
    end

    def to_s
      self.request_pattern.to_s
    end

    def self.from_request_signature(signature)
      stub = self.new(signature.method.to_sym, signature.uri.to_s)

      if signature.body.to_s != ''
        body = if signature.url_encoded?
          WebMock::Util::QueryMapper.query_to_values(signature.body, :notation => Config.instance.query_values_notation)
        else
          signature.body
        end
        stub.with(:body => body)
      end

      if (signature.headers && !signature.headers.empty?)
        stub.with(:headers => signature.headers)
      end
      stub
    end
  end
end
