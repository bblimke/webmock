#This file is taken from FakeWeb (fakeweb.rubyforge.org/) and adopted

module WebMock
  module Utility #:nodoc:

    def self.decode_userinfo_from_header(header)
      header.sub(/^Basic /, "").unpack("m").first
    end

    def self.encode_unsafe_chars_in_userinfo(userinfo)
      unsafe_in_userinfo = /[^#{URI::REGEXP::PATTERN::UNRESERVED};&=+$,]|^(#{URI::REGEXP::PATTERN::ESCAPED})/
      userinfo.split(":").map { |part| URI.escape(part, unsafe_in_userinfo) }.join(":")
    end

    def self.strip_default_port_from_uri(uri)
      case uri
      when %r{^http://}  then uri.sub(%r{:80(/|$)}, '\1')
      when %r{^https://} then uri.sub(%r{:443(/|$)}, '\1')
      else uri
      end
    end

    def self.puts_warning_for_net_http_around_advice_libs_if_needed
      libs = {"Samuel" => defined?(Samuel)}
      warnings = libs.select { |_, loaded| loaded }.map do |name, _|
        <<-TEXT.gsub(/ {10}/, '')
          \e[1mWarning: WebMock was loaded after #{name}\e[0m
          * #{name}'s code is being ignored when a request is handled by WebMock,
            because both libraries work by patching Net::HTTP.
          * To fix this, just reorder your requires so that WebMock is before #{name}.
        TEXT
      end
      $stderr.puts "\n" + warnings.join("\n") + "\n" if warnings.any?
    end

    def self.record_loaded_net_http_replacement_libs
      libs = {"RightHttpConnection" => defined?(RightHttpConnection)}
      @loaded_net_http_replacement_libs = libs.map { |name, loaded| name if loaded }.compact
    end

    def self.puts_warning_for_net_http_replacement_libs_if_needed
      libs = {"RightHttpConnection" => defined?(RightHttpConnection)}
      warnings = libs.select { |_, loaded| loaded }.
                    reject { |name, _| @loaded_net_http_replacement_libs.include?(name) }.
                    map do |name, _|
        <<-TEXT.gsub(/ {10}/, '')
          \e[1mWarning: #{name} was loaded after WebMock\e[0m
          * WebMock's code is being ignored, because #{name} replaces parts of
            Net::HTTP without deferring to other libraries. This will break Net::HTTP requests.
          * To fix this, just reorder your requires so that #{name} is before WebMock.
        TEXT
      end
      $stderr.puts "\n" + warnings.join("\n") + "\n" if warnings.any?
    end

    def self.normalize_headers(headers)
      return nil unless headers
      array = headers.map { |name, value|
        [name.to_s.split(/_|-/).map { |segment| segment.capitalize }.join("-"), value.to_s]
      }
      Hash[*array.flatten]
    end

  end
end
