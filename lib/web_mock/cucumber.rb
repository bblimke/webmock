require 'web_mock'
require 'web_mock/rspec/matchers'

World(WebMock::API, WebMock::Matchers)

After do
  WebMock.reset!
end
