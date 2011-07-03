require 'spec_helper'
require 'stringio'

describe WebMock do
  it 'prints a warning regarding requiring WebMock 2 properly' do
    original_stream = $stderr
    $stderr = StringIO.new

    require 'webmock'

    $stderr.rewind
    $stderr.string.chomp.should eql(
      %{require "webmock" is deprecated and will be removed in WebMock 2.1. Use require "web_mock" instead.}
    )

    $stderr = original_stream
  end
end
