module WebMock

  class URL

    def self.normalize_uri(uri)
      return uri if uri.is_a?(Regexp)
      normalized_uri =
      case uri
      when URI then uri
      when String
        uri = 'http://' + uri unless uri.match('^https?://')
        URI.parse(uri)
      end
      normalized_uri.query = sort_query_params(normalized_uri.query)
      normalized_uri.normalize
    end

    def self.variations_of_uri_as_strings(uri_object)
      normalized_uri = normalize_uri(uri_object.dup)
      normalized_uri_string = normalized_uri.to_s

      variations = [normalized_uri_string]

      # if the port is implied in the original, add a copy with an explicit port
      if normalized_uri.default_port == normalized_uri.port
        variations << normalized_uri_string.sub(
          /#{Regexp.escape(normalized_uri.request_uri)}$/,
          ":#{normalized_uri.port}#{normalized_uri.request_uri}")
      end

      variations
    end

    private

    def self.sort_query_params(query)
      if query.nil? || query.empty?
        nil
      else
        query.split('&').sort.join('&')
      end
    end

  end

end
