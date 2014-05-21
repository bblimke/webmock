require 'spec_helper'

describe WebMock::Util::QueryMapper do
  let(:query_mapper) { described_class }

  it "converts query to values" do
    query = "key=value&other_key=other_value"
    values = { 'key' => 'value', 'other_key' => 'other_value' }
    expect(query_mapper.query_to_values query).to eq values
  end

  it 'converts values to a query string' do
    query = "key=value&other_key=other_value"
    values = [['key','value'],['other_key','other_value']]
    expect(query_mapper.values_to_query values).to eq query
  end

  it 'converts values with missing keys to a query string' do
    query = "=value"
    values = { '' => 'value' }
    expect(query_mapper.values_to_query values).to eq query
  end

  it 'converts values with nil keys to a query string' do
    query = "=value"
    values = { nil => 'value' }
    expect(query_mapper.values_to_query values).to eq query
  end

  it 'converts array values, vice versa' do
    query = "one%5B%5D=1&one%5B%5D=2"
    values = {"one" => ["1","2"]}
    expect(query_mapper.values_to_query values).to eq query
    expect(query_mapper.query_to_values query).to eq values
  end

  it 'converts hash values, vice versa' do
    query = "one%5Ba%5D=1&one%5Bb%5D=2"
    values = {"one" => {"a" => "1", "b" => "2"}}
    expect(query_mapper.values_to_query values).to eq query
    expect(query_mapper.query_to_values query).to eq values
  end
end
