require 'spec_helper'

describe WebMock::Util::QueryMapper do
  subject { described_class }

  context '#query_to_values' do
    it 'should raise on invalid notation' do
      query = 'a=&b=c'
      expect { subject.query_to_values(query, {:notation => 'foo'}) }.to raise_error(
        ArgumentError,
        'Invalid notation. Must be one of: [:flat, :dot, :subscript, :flat_array].'
      )
    end

    it 'should parse hash queries' do
      # {"one" => {"two" => {"three" => ["four", "five"]}}}
      query = 'one%5Btwo%5D%5Bthree%5D%5B%5D=four&one%5Btwo%5D%5Bthree%5D%5B%5D=five'
      hsh = subject.query_to_values(query)
      expect(hsh['one']['two']['three']).to eq(%w(four five))
    end

    it 'should parse one nil value queries' do
      # {'a' => nil, 'b' => 'c'}
      query = 'a=&b=c'
      hsh = subject.query_to_values(query)
      expect(hsh['a']).to be_empty
      expect(hsh['b']).to eq('c')
    end

    it 'should parse array queries' do
      # {"one" => ["foo", "bar"]}
      query = 'one%5B%5D=foo&one%5B%5D=bar'
      hsh = subject.query_to_values(query)
      expect(hsh['one']).to eq(%w(foo bar))
    end

    it 'should parse string queries' do
      # {"one" => "two", "three" => "four"}
      query = 'one=two&three=four'
      hsh = subject.query_to_values(query)
      expect(hsh).to  eq({'one' => 'two', 'three' => 'four'})
    end

    it 'should parse nested queries' do
      # [{"b"=>[{"c"=>[{"d"=>["1", {"e"=>"2"}]}]}]}]
      query = 'a%5B%5D%5Bb%5D%5B%5D%5Bc%5D%5B%5D%5Bd%5D%5B%5D=1&a%5B%5D%5Bb%5D%5B%5D%5Bc%5D%5B%5D%5Bd%5D%5B%5D%5Be%5D=2'
      hsh = subject.query_to_values(query)
      expect(hsh['a'][0]['b'][0]['c'][0]['d'][0]).to eq('1')
      expect(hsh['a'][0]['b'][0]['c'][0]['d'][1]['e']).to eq('2')
    end
  end

  context '#to_query' do
    it 'should transform nil value' do
      expect(subject.to_query('a', nil)).to eq('a')
    end
    it 'should transform string value' do
      expect(subject.to_query('a', 'b')).to eq('a=b')
    end
    it 'should transform hash value' do
      expect(subject.to_query('a', {'key' => 'value'})).to eq('a[key]=value')
    end
    it 'should transform hash value with keys that are symbols' do
      expect(subject.to_query('a', {:key => 'value'})).to eq('a[key]=value')
    end
    it 'should transform array value' do
      expect(subject.to_query('a', ['b', 'c'])).to eq('a[0]=b&a[1]=c')
    end
    it 'should transform boolean values' do
      expect(subject.to_query('a', true)).to eq('a=true')
      expect(subject.to_query('a', false)).to eq('a=false')
    end
  end

  context '#values_to_query' do
    it 'converts values to a query string' do
      query = "key=value&other_key=other_value"
      values = [['key','value'],['other_key','other_value']]
      expect(subject.values_to_query values).to eq query
    end

    it 'converts values with missing keys to a query string' do
      query = "=value"
      values = { '' => 'value' }
      expect(subject.values_to_query values).to eq query
    end

    it 'converts values with nil keys to a query string' do
      query = "=value"
      values = { nil => 'value' }
      expect(subject.values_to_query values).to eq query
    end
  end

  it 'converts array values, vice versa' do
    query = "one%5B%5D=1&one%5B%5D=2" # one[]=1&one[]=2
    values = {"one" => ["1","2"]}
    expect(subject.values_to_query values).to eq query
    expect(subject.query_to_values query).to eq values
  end

  it 'converts hash values, vice versa' do
    query = "one%5Ba%5D=1&one%5Bb%5D=2" # one[a]=1&one[b]=2
    values = {"one" => {"a" => "1", "b" => "2"}}
    expect(subject.values_to_query values).to eq query
    expect(subject.query_to_values query).to eq values
  end

  it 'converts complex nested values, vice versa' do
    query = "one%5B%5D[foo]=bar&one%5B%5D[zoo]=car" # one[][foo]=bar&one[][zoo]=car
    values = {"one" => [{"foo" => "bar"}, {"zoo" => "car"}]}
    expect(subject.values_to_query values).to eq query
    expect(subject.query_to_values query).to eq values
  end
end
