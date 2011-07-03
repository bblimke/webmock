require 'singleton'

require 'addressable/uri'
require 'crack'

require 'web_mock/deprecation'
require 'web_mock/version'

require 'web_mock/errors'

require 'web_mock/util/uri'
require 'web_mock/util/headers'
require 'web_mock/util/hash_counter'
require 'web_mock/util/hash_keys_stringifier'

require 'web_mock/request_pattern'
require 'web_mock/request_signature'
require 'web_mock/responses_sequence'
require 'web_mock/request_stub'
require 'web_mock/response'

require 'web_mock/stub_request_snippet'

require 'web_mock/assertion_failure'
require 'web_mock/request_execution_verifier'
require 'web_mock/config'
require 'web_mock/callback_registry'
require 'web_mock/request_registry'
require 'web_mock/stub_registry'
require 'web_mock/api'
require 'web_mock/web_mock'

require 'web_mock/adapters/net_http'
require 'web_mock/adapters/httpclient'
require 'web_mock/adapters/patron'
require 'web_mock/adapters/curb'
require 'web_mock/adapters/em_http_request'
