# frozen_string_literal: true

module WebMock
  class CallbackRegistry
    @@callbacks = []

    def self.add_callback(options, block)
      @@callbacks << {options: options, block: block}
    end

    def self.callbacks
      @@callbacks
    end

    def self.invoke_callbacks(options, request_signature, response)
      return if @@callbacks.empty?
      CallbackRegistry.callbacks.each do |callback|
        callback[:block].call(request_signature, response) if runs_for?(callback, options)
      end
    end

    # Whether invoke_callbacks would run any callback for a request with
    # these options, given each callback's except and real_requests_only.
    def self.any_callbacks_for?(options)
      @@callbacks.any? { |callback| runs_for?(callback, options) }
    end

    def self.runs_for?(callback, options)
      except = callback[:options][:except]
      real_only = callback[:options][:real_requests_only]
      !(except && except.include?(options[:lib])) && (!real_only || options[:real_request])
    end
    private_class_method :runs_for?

    def self.reset
      @@callbacks = []
    end

    def self.any_callbacks?
      !@@callbacks.empty?
    end

  end
end
