# frozen_string_literal: true

module WebMock
  module Util
    module ContentType
      BODY_FORMATS = {
        'text/xml'               => :xml,
        'application/xml'        => :xml,
        'application/json'       => :json,
        'text/json'              => :json,
        'application/javascript' => :json,
        'text/javascript'        => :json,
        'text/html'              => :html,
        'application/x-yaml'     => :yaml,
        'text/yaml'              => :yaml,
        'text/plain'             => :plain
      }

      def self.media_type(content_type)
        content_type.to_s.scrub.split(';', 2).first.to_s.strip.downcase
      end

      def self.url_encoded?(content_type)
        media_type(content_type) == 'application/x-www-form-urlencoded'
      end

      def self.body_format(content_type)
        type = media_type(content_type)

        BODY_FORMATS.fetch(type) do
          case type
          when %r{\A[^/\s]+/[^/\s]+\+json\z} then :json
          when %r{\A[^/\s]+/[^/\s]+\+xml\z} then :xml
          end
        end
      end
    end
  end
end
