# frozen_string_literal: true

begin
  require 'curb'
rescue LoadError
  # curb not found
end

if defined?(Curl)
  unsupported_curb_versions = ['0.8.7']

  # Curl::Easy#perform raises "cannot define finalizer for TrueClass" on Ruby 2.6
  # in curb 1.3.0 through 1.3.5. Fixed in curb 1.3.6. See https://github.com/taf2/curb/issues/478
  unsupported_curb_versions += %w[1.3.0 1.3.1 1.3.2 1.3.3 1.3.4 1.3.5] if RUBY_VERSION < '2.7'

  WebMock::VersionChecker.new('Curb', Curl::CURB_VERSION, '0.7.16', nil, unsupported_curb_versions).check_version!

  module WebMock
    module HttpLibAdapters
      class CurbAdapter < HttpLibAdapter
        adapter_for :curb

        OriginalCurlEasy = Curl::Easy unless const_defined?(:OriginalCurlEasy)

        OriginalCurlMulti = Curl::Multi unless const_defined?(:OriginalCurlMulti)

        def self.enable!
          Curl.send(:remove_const, :Easy)
          Curl.send(:const_set, :Easy, Curl::WebMockCurlEasy)
          Curl.send(:remove_const, :Multi)
          Curl.send(:const_set, :Multi, Curl::WebMockCurlMulti)
        end

        def self.disable!
          Curl.send(:remove_const, :Easy)
          Curl.send(:const_set, :Easy, OriginalCurlEasy)
          Curl.send(:remove_const, :Multi)
          Curl.send(:const_set, :Multi, OriginalCurlMulti)
        end

        # Borrowed from Patron:
        # http://github.com/toland/patron/blob/master/lib/patron/response.rb
        def self.parse_header_string(header_string)
          status, headers = nil, {}

          header_string.split(/\r\n/).each do |header|
            if header =~ %r{\AHTTP/(1\.[01]|2) (\d{3})\s*(.*)}
              status = $3
            else
              parts = header.split(':', 2)
              unless parts.empty?
                parts[1].strip! unless parts[1].nil?
                if headers.has_key?(parts[0])
                  headers[parts[0]] = [headers[parts[0]]] unless headers[parts[0]].kind_of? Array
                  headers[parts[0]] << parts[1]
                else
                  headers[parts[0]] = parts[1]
                end
              end
            end
          end

          return status, headers
        end
      end
    end
  end

  module Curl
    class WebMockCurlMulti < Curl::Multi
      # Intercept the native attachment boundary, retaining curb's public add,
      # remove, request table and native event loop for allowed transfers.
      def _add(easy)
        return super if easy.webmock_performing_easy?

        begin
          signature, response = easy.webmock_request
        rescue Exception # NetConnectNotAllowedError inherits directly from Exception.
          # Older curb versions insert into requests before calling _add.
          requests.delete(easy.object_id)
          easy.webmock_restore_multi_url
          raise
        end
        if response
          easy.multi = self
          webmock_pending[easy.object_id] = [easy, signature, response]
        else
          easy.webmock_record_multi_request(signature)
          super
        end
      end

      def _remove(easy)
        if webmock_pending.delete(easy.object_id)
          easy.multi = nil
          return self
        end
        super
      end

      def perform(&block)
        complete_webmock_requests
        super do
          begin
            complete_webmock_requests
            block.call if block
          end until webmock_pending.empty?
        end
      end

      private

      def webmock_pending
        @webmock_pending ||= {}
      end

      def complete_webmock_requests
        until webmock_pending.empty?
          easy, signature, response = webmock_pending.values.first
          # Detach before callbacks so they can remove or requeue handles.
          remove(easy)
          if easy.webmock_follow_multi_redirect(signature, response)
            add(easy)
          else
            begin
              easy.multi = self
              easy.webmock_complete_multi_request(signature, response)
            ensure
              easy.multi = nil if easy.multi == self && !requests.key?(easy.object_id)
            end
          end
        end
      end
    end

    class WebMockCurlEasy < Curl::Easy
      # Curb's native PostField cannot be duplicated. Its public attributes
      # describe the field without running a content callback or opening a file.
      MultipartField = Struct.new(:name, :content, :content_type, :local_file, :remote_file) do
        def self.from(field)
          new(*members.map { |attribute| field.public_send(attribute)&.to_s })
        end

        def to_s
          return super unless content && !local_file && !remote_file
          Curl::PostField.content(name, content).to_s
        end

        def initialize_copy(original)
          super
          each_pair { |attribute, value| self[attribute] = value.dup }
        end
      end
      private_constant :MultipartField

      def webmock_request
        @webmock_method ||= :get
        clear_webmock_response
        webmock_clear_multi_request
        request_signature = build_request_signature
        recorded = signature_for_history(request_signature)
        if request_signature.method == :put && @put_data.respond_to?(:read)
          request_signature = request_signature.with_upload_body(@put_data)
        end

        webmock_response = WebMock::StubRegistry.instance.response_for_request(
          request_signature, record: recorded)
        unless webmock_response || WebMock.net_connect_allowed?(request_signature.uri)
          raise WebMock::NetConnectNotAllowedError.new(request_signature)
        end
        [request_signature, webmock_response]
      end

      def curb_or_webmock
        request_signature, webmock_response = webmock_request
        if webmock_response
          build_curb_response(webmock_response)
          WebMock::CallbackRegistry.invoke_callbacks(
            {lib: :curb}, request_signature, webmock_response)
          invoke_curb_callbacks
          true
        else
          @webmock_performing_easy = true
          res = yield
          if WebMock::CallbackRegistry.any_callbacks?
            webmock_response = build_webmock_response
            WebMock::CallbackRegistry.invoke_callbacks(
              {lib: :curb, real_request: true}, request_signature,
                webmock_response)
          end
          res
        end
      ensure
        @webmock_performing_easy = false
      end

      def webmock_performing_easy?
        @webmock_performing_easy
      end

      def webmock_record_multi_request(signature)
        @webmock_multi_request = signature
        on_complete(&@on_complete)
      end

      def webmock_clear_multi_request
        @webmock_multi_request = nil
      end

      %w[body header].each do |part|
        define_method("on_#{part}") do |&block|
          instance_variable_set("@on_#{part}", block)
          if block
            super() do |data|
              if @webmock_multi_request
                buffer = instance_variable_get("@webmock_#{part}") || +""
                buffer << data
                instance_variable_set("@webmock_#{part}", buffer)
              end
              block.call(data)
            end
          else
            super(&block)
          end
        end
      end

      def on_complete(&block)
        @on_complete = block
        super do |easy|
          signature = @webmock_multi_request
          webmock_restore_multi_url
          webmock_clear_multi_request
          if signature && WebMock::CallbackRegistry.any_callbacks?
            WebMock::CallbackRegistry.invoke_callbacks(
              {lib: :curb, real_request: true}, signature, build_webmock_response)
          end
          block.call(easy) if block
        end
      end

      def webmock_follow_multi_redirect(signature, response)
        location = response.headers && response.headers['Location']
        return false unless follow_location? && (300..399).include?(response.status[0]) && location
        return false if response.should_timeout || response.exception

        @webmock_multi_redirects ||= 0
        limit = max_redirects || 50
        if limit >= 0 && @webmock_multi_redirects >= limit
          @webmock_last_result = 47 # CURLE_TOO_MANY_REDIRECTS
          return false
        end
        WebMock::CallbackRegistry.invoke_callbacks({lib: :curb}, signature, response)
        @webmock_multi_original_url ||= url
        @webmock_multi_redirects += 1
        self.url = WebMock::Util::URI.heuristic_parse(url).join(location).to_s
        true
      end

      def webmock_restore_multi_url
        return unless @webmock_multi_original_url
        @last_effective_url = last_effective_url
        self.url = @webmock_multi_original_url
        @webmock_multi_original_url = @webmock_multi_redirects = nil
      end

      def webmock_complete_multi_request(signature, response)
        if response.should_timeout
          @body_str = ""
          @header_str = ""
          @response_code = 0
          @webmock_last_result = 28 # CURLE_OPERATION_TIMEDOUT
        else
          build_curb_response(response, follow_redirects: false)
          @webmock_last_result ||= 0
        end
        webmock_restore_multi_url
        WebMock::CallbackRegistry.invoke_callbacks({lib: :curb}, signature, response)
        invoke_curb_callbacks(multi: true)
      end

      def last_result
        @webmock_last_result || super
      end

      def clear_webmock_response
        @body_str = @header_str = @response_code = @content_type = nil
        @last_effective_url = @transfer_encoding = @webmock_last_result = nil
        @webmock_body = @webmock_header = nil
      end

      def signature_for_history(signature)
        body = signature.body
        return signature unless body.is_a?(Curl::PostField) || (body.is_a?(Array) && multipart_form_post?)
        signature.with_body_values { |field| MultipartField.from(field) }
      end
      private :signature_for_history

      def build_request_signature
        method = @webmock_method.to_s.downcase.to_sym

        uri = WebMock::Util::URI.heuristic_parse(self.url)
        uri.path = uri.normalized_path.gsub("[^:]//","/")

        headers = headers_as_hash(self.headers).merge(basic_auth_headers)

        request_body = case method
        when :post, :patch
          self.post_body || @post_body
        when :put
          if @put_data.respond_to?(:read)
            WebMock::Util::UploadBody.read(@put_data, headers)
          else
            @put_data
          end
        else
          nil
        end

        if @on_debug
          @on_debug.call("Trying 127.0.0.1...\r\n", 0)
          @on_debug.call('Connected to ' + uri.hostname + "\r\n", 0)
          @debug_method = method.upcase
          @debug_path = uri.path
          @debug_host = uri.hostname
          http_request = ["#{@debug_method} #{@debug_path} HTTP/1.1"]
          http_request << "Host: #{uri.hostname}"
          headers.each do |name, value|
            http_request << "#{name}: #{value}"
          end
          @on_debug.call(http_request.join("\r\n") + "\r\n\r\n", 2)
          if request_body
            @on_debug.call(request_body + "\r\n", 4)
            @on_debug.call(
              "upload completely sent off: #{request_body.bytesize}"\
              " out of #{request_body.bytesize} bytes\r\n", 0
            )
          end
        end

        request_signature = WebMock::RequestSignature.new(
          method,
          uri.to_s,
          body: request_body,
          headers: headers
        )
        request_signature
      end

      def headers_as_hash(headers)
        if headers.is_a?(Array)
          headers.inject({}) {|hash, header|
            name, value = header.split(":", 2).map(&:strip)
            hash[name] = value
            hash
          }
        else
          headers
        end
      end

      def basic_auth_headers
        if self.username
          {'Authorization' => WebMock::Util::Headers.basic_auth_header(self.username, self.password)}
        else
          {}
        end
      end

      def build_curb_response(webmock_response, follow_redirects: true)
        raise Curl::Err::TimeoutError if webmock_response.should_timeout
        webmock_response.raise_error_if_any

        @body_str = webmock_response.body
        @response_code = webmock_response.status[0]

        @header_str = "HTTP/1.1 #{webmock_response.status[0]} #{webmock_response.status[1]}\r\n".dup

        @on_debug.call(@header_str, 1) if @on_debug

        if webmock_response.headers
          # Each cookie gets a line of its own, as servers send them.
          @header_str << webmock_response.headers.flat_map do |k,v|
            values = k == "Set-Cookie" ? Array(v) : [v.is_a?(Array) ? v.join(", ") : v]
            values.map do |value|
              header = "#{k}: #{value}"
              @on_debug.call(header + "\r\n", 1) if @on_debug
              header
            end
          end.join("\r\n")
          @on_debug.call("\r\n", 1) if @on_debug

          location = webmock_response.headers['Location']
          if follow_redirects && self.follow_location? && location
            @last_effective_url = location
            webmock_follow_location(location)
          end

          @content_type = webmock_response.headers["Content-Type"]
          @transfer_encoding = webmock_response.headers["Transfer-Encoding"]
        end

        @last_effective_url ||= self.url
      end

      def webmock_follow_location(location)
        first_url = self.url
        self.url = location

        curb_or_webmock do
          send( :http, {'method' => @webmock_method} )
        end

        self.url = first_url
      end

      def invoke_curb_callbacks(multi: false)
        @on_progress.call(0.0,1.0,0.0,1.0) if @on_progress
        self.header_str.lines.each { |header_line| @on_header.call header_line } if @on_header
        if @on_body
          if chunked_response?
            self.body_str.each do |chunk|
              @on_body.call(chunk)
            end
          else
            @on_body.call(self.body_str)
          end
        end
        completed_code = response_code
        completed_result = last_result if multi
        @on_complete.call(self) if @on_complete

        if multi && completed_result != 0
          @on_failure.call(self, Curl::Easy.error(completed_result)) if @on_failure
          return
        end

        case completed_code
        when 200..299
          @on_success.call(self) if @on_success
        when 300..399
          @on_redirect.call(self, Curl::Easy.error(0)) if multi && @on_redirect && max_redirects != 0
        when 400..499
          @on_missing.call(self, multi ? Curl::Easy.error(0) : self.response_code) if @on_missing
        when 500..599
          @on_failure.call(self, multi ? Curl::Easy.error(0) : self.response_code) if @on_failure
        end
      end

      def chunked_response?
        defined?( @transfer_encoding ) && @transfer_encoding == 'chunked' && self.body_str.respond_to?(:each)
      end

      def build_webmock_response
        status, headers =
         WebMock::HttpLibAdapters::CurbAdapter.parse_header_string((@webmock_header || self.header_str).to_s)

        if @on_debug
          http_response = ["HTTP/1.0 #{@debug_method} #{@debug_path}"]
          headers.each do |name, value|
            http_response << "#{name}: #{value}"
          end
          http_response << self.body_str
          @on_debug.call(http_response.join("\r\n") + "\r\n", 3)
          @on_debug.call("Connection #0 to host #{@debug_host} left intact\r\n", 0)
        end

        webmock_response = WebMock::Response.new
        webmock_response.status = [self.response_code, status]
        webmock_response.body = @webmock_body || self.body_str
        webmock_response.headers = headers
        webmock_response
      end

      ###
      ### Mocks of Curl::Easy methods below here.
      ###

      def http(method)
        @webmock_method = method
        super
      end

      %w[ get head delete ].each do |verb|
        define_method "http_#{verb}" do
          @webmock_method = verb
          super()
        end
      end

      # curb has http_patch since 1.0.8.
      if method_defined?(:http_patch)
        def http_patch *data
          @webmock_method = :patch
          @post_body = data.join('&') unless data.empty?
          super
        end
      end

      def http_put(data = nil)
        # put_data= can supply the upcoming request's body until perform resets the method.
        data = @put_data if data.nil? && @webmock_method == :put
        @webmock_method = :put
        @put_data = data
        return super('') if data.nil?
        return super(data) if data.is_a?(String) || data.respond_to?(:read) || multipart_form_post?

        # Curb joins other positional arguments as it would form fields.
        @put_data = [data].join('&')
        super(@put_data)
      ensure
        @put_data = nil
      end
      alias put http_put

      def http_post *data
        @webmock_method = :post
        @post_body = data.join('&') unless data.empty?
        super
      end
      alias post http_post

      def perform
        @webmock_method ||= :get
        curb_or_webmock { super }
      ensure
        reset_webmock_method
        # The body given to http_post or http_patch is for this request only.
        @post_body = nil
      end

      def put_data=(data)
        body = data.respond_to?(:read) ? data : data&.to_s
        super(body)
        @webmock_method = :put
        @put_data = body
        data
      end

      def post_body= data
        @webmock_method = :post
        super
      end

      def delete= value
        @webmock_method = :delete if value
        super
      end

      def head= value
        @webmock_method = :head if value
        super
      end

      def verbose=(verbose)
        @verbose = verbose
      end

      def verbose?
        @verbose ||= false
      end

      def body_str
        @body_str ||= super
      end
      alias body body_str

      def response_code
        @response_code ||= super
      end
      alias code response_code

      def header_str
        @header_str ||= super
      end
      alias head header_str

      def last_effective_url
        @last_effective_url ||= super
      end

      def content_type
        @content_type ||= super
      end

      %w[ success failure missing redirect progress debug ].each do |callback|
        class_eval <<-METHOD, __FILE__, __LINE__
          def on_#{callback} &block
            @on_#{callback} = block
            super
          end
        METHOD
      end

      def reset_webmock_method
        @webmock_method = :get
      end

      def reset
        @put_data = nil
        clear_webmock_response
        webmock_clear_multi_request
        reset_webmock_method
        @webmock_multi_original_url = @webmock_multi_redirects = nil
        super
      end
    end
  end
end
