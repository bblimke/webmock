require 'spec_helper'

describe WebMock::Util::HashKeysStringifier do

  it "should recursively stringify all symbol keys" do
    hash = {
      a: {
        b: [
          {
            c: [{d: "1"}]
          }
        ]
      }
    }
    stringified = {
      'a' => {
        'b' => [
          {
            'c' => [{'d' => "1"}]
          }
        ]
      }
    }
    expect(WebMock::Util::HashKeysStringifier.stringify_keys!(hash, deep: true)).to eq(stringified)
  end

  it "should keep a nested RSpec matcher without keys to change" do
    ids = [1]
    matcher = RSpec::Mocks::ArgumentMatchers::ArrayIncludingMatcher.new(ids)
    expect(WebMock::Util::HashKeysStringifier.stringify_keys!({ids: matcher}, deep: true)["ids"]).to equal(matcher)
  end

  it "should give string keys to a nested RSpec matcher" do
    matcher = RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher.new({a: 1})
    stringified = WebMock::Util::HashKeysStringifier.stringify_keys!({m: matcher}, deep: true)["m"]
    expect(stringified).to be_a(RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher)
    expect(stringified.instance_variable_get(:@expected)).to eq({"a" => 1})
  end

end
