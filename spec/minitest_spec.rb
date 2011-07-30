require 'spec_helper'

SCRIPT = <<-CODE
require "rubygems"
gem "minitest"
require "minitest/autorun"
require "webmock/minitest"

class MiniTestWebMockTest < MiniTest::Unit::TestCase
  def test_that_passes
    stub_request(:any, "http://example.com")

    r = Net::HTTP.get_response(URI("http://example.com"))

    assert_equal 200, r.code.to_i
  end

  def test_that_fails
    r = Net::HTTP.get_response(URI("http://example.com"))

    assert_equal 200, r.code.to_i
  end
end
CODE

describe "MiniTest and WebMock" do
  def run_test
    # borrowed from: http://stackoverflow.com/questions/213368
    ruby = File.join(Config::CONFIG.values_at('bindir', 'ruby_install_name')).
      sub(/.*\s.*/m, '"\&"')

    # This value makes it so the tests run in the order defined.
    seed = 9001

    `#{ruby} -Ilib -e '#{SCRIPT}' -- --verbose --seed #{seed}`
  end

  it "has access to WebMock::API's methods" do
    re = /^MiniTestWebMockTest#test_that_passes = [0-9]\.[0-9]+ s = \.$/
    run_test.should match re
  end

  it "clears WebMock's registry between tests" do
    re = /test_that_fails\(MiniTestWebMockTest\):\nWebMock::NetConnectNotAllowedError:/m
    run_test.should match re
  end
end
