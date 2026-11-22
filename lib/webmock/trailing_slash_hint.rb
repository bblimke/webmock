# frozen_string_literal: true

module WebMock
  # Stubs treat "/users" and "/users/" as different URLs, since servers can
  # treat them differently. When a slash at the end of the path is the only
  # reason a request doesn't match, failure messages point it out. See #864.
  module TrailingSlashHint
    STUB_HINTS = {
      added: "Hint: the request URL ends with a slash and the URL of this stub doesn't, " \
             "so they are different URLs.",
      removed: "Hint: the URL of this stub ends with a slash and the request URL doesn't, " \
               "so they are different URLs."
    }.freeze

    EXPECTATION_HINTS = {
      added: "Hint: a request was made to the expected URL with a slash at the end, " \
             "which is a different URL.",
      removed: "Hint: a request was made to the expected URL without the slash at the end, " \
               "which is a different URL."
    }.freeze

    # :added when the request path ends with a slash that the URL of the
    # pattern doesn't have, :removed for the reverse, and nil otherwise. Only
    # for a URL given as a string, and only the method and the URL without
    # its query are compared: the hint is about the path, and building a
    # failure message must not run code given to with, or raise.
    def self.difference(request_pattern, request_signature)
      patterns = parts_of(request_pattern)
      return unless patterns.all? { |pattern| pattern.is_a?(RequestPattern) }
      return unless patterns.first.uri_pattern.is_a?(URIStringPattern)

      path = request_signature.uri.path
      return if path.empty? || path == "/"

      ends_with_slash = path.end_with?("/")
      toggled = request_signature.uri.dup
      toggled.path = ends_with_slash ? path.chomp("/") : "#{path}/"
      # Other parts, such as the conditions of an expectation, match any URI.
      return unless patterns.first.uri_pattern.matches_without_query?(toggled)
      return unless patterns.all? { |pattern| pattern.method_pattern.matches?(request_signature.method) }

      ends_with_slash ? :added : :removed
    rescue StandardError
      nil
    end

    # A pattern made of parts that must all match, such as an RSpec expectation
    # with conditions, responds to #patterns. A stub stands for its pattern.
    def self.parts_of(request_pattern)
      parts = request_pattern.respond_to?(:patterns) ? request_pattern.patterns : [request_pattern]
      parts.map { |part| part.is_a?(RequestStub) ? part.request_pattern : part }
    end
    private_class_method :parts_of
  end
end
