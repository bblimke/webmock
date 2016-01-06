require 'singleton'

require 'addressable/uri'
require 'addressable/template'
require 'crack/xml'

require 'webmock/deprecation'
require 'webmock/version'

require 'webmock/errors'

require 'webmock/util/query_mapper'
require 'webmock/util/uri'
require 'webmock/util/headers'
require 'webmock/util/hash_counter'
require 'webmock/util/hash_keys_stringifier'
require 'webmock/util/json'
require 'webmock/util/version_checker'
require 'webmock/util/hash_validator'

require 'webmock/matchers/hash_including_matcher'

require 'webmock/request_pattern'
require 'webmock/request_signature'
require 'webmock/responses_sequence'
require 'webmock/request_stub'
require 'webmock/response'
require 'webmock/rack_response'

require 'webmock/stub_request_snippet'
require 'webmock/request_signature_snippet'
require 'webmock/request_body_diff'

require 'webmock/assertion_failure'
require 'webmock/request_execution_verifier'
require 'webmock/config'
require 'webmock/callback_registry'
require 'webmock/request_registry'
require 'webmock/stub_registry'
require 'webmock/api'

require 'webmock/http_lib_adapters/http_lib_adapter_registry'
require 'webmock/http_lib_adapters/http_lib_adapter'
require 'webmock/http_lib_adapters/net_http'
require 'webmock/http_lib_adapters/http_rb_adapter'
require 'webmock/http_lib_adapters/httpclient_adapter'
require 'webmock/http_lib_adapters/patron_adapter'
require 'webmock/http_lib_adapters/curb_adapter'
require 'webmock/http_lib_adapters/em_http_request_adapter'
require 'webmock/http_lib_adapters/typhoeus_hydra_adapter'
require 'webmock/http_lib_adapters/excon_adapter'
require 'webmock/http_lib_adapters/manticore_adapter'

require 'webmock/webmock'

if RUBY_VERSION <= "1.8.7" && Addressable::VERSION::STRING >= "2.4.0"
  raise StandardError,
    <<-ERR
    \n\e[31m
    Addressable dropped support for Ruby 1.8.7 on version 2.4.0,

    please add the following to your Gemfile to be able to use WebMock:

    gem 'addressable', '< 2.4.0'\e[0m\n
  ERR
end
