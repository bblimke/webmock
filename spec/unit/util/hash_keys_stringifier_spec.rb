require 'spec_helper'

describe WebMock::Util::HashKeysStringifier do

  it "should recursively stringify all symbol keys" do
    hash = {
      :a => {
        :b => [
          {
            :c => [{:d => "1"}]
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
    expect(WebMock::Util::HashKeysStringifier.stringify_keys!(hash, :deep => true)).to eq(stringified)
  end

end
