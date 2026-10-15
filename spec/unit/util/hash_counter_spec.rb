require 'spec_helper'

describe WebMock::Util::HashCounter do

  it "should return 0 for non existing key" do
    expect(WebMock::Util::HashCounter.new.get(:abc)).to eq(0)
  end

  it "should increase the returned value on every put with the same key" do
    counter = WebMock::Util::HashCounter.new
    counter.put(:abc)
    expect(counter.get(:abc)).to eq(1)
    counter.put(:abc)
    expect(counter.get(:abc)).to eq(2)
  end

  it "should only increase value for given key provided to put" do
    counter = WebMock::Util::HashCounter.new
    counter.put(:abc)
    expect(counter.get(:abc)).to eq(1)
    expect(counter.get(:def)).to eq(0)
  end

  it "should return the key it holds, a copy of the first one put for an equal key" do
    counter = WebMock::Util::HashCounter.new
    first = WebMock::RequestSignature.new(:get, "www.example.com")
    stored = counter.put(first)
    expect(stored).to eq(first)
    expect(stored).not_to equal(first)
    # Enough other keys that Ruby stores the hash as a full table.
    20.times { |i| counter.put(WebMock::RequestSignature.new(:get, "www.example.com/#{i}")) }
    expect(counter.put(WebMock::RequestSignature.new(:get, "www.example.com"))).to equal(stored)
    expect(counter.get(first)).to eq(2)
  end

  it "should keep counting a key that its caller changes after putting it" do
    counter = WebMock::Util::HashCounter.new
    buffer = +"first"
    counter.put(WebMock::RequestSignature.new(:post, "www.example.com", body: buffer))
    buffer.replace("second")
    counter.put(WebMock::RequestSignature.new(:post, "www.example.com", body: "first"))
    expect(counter.get(WebMock::RequestSignature.new(:post, "www.example.com", body: "first"))).to eq(2)
  end

  it "should let a select block use the counter" do
    counter = WebMock::Util::HashCounter.new
    counter.put(:a)
    expect(counter.select { |key, _| counter.put(:b); key == :a }).to eq(a: 1)
    expect(counter.get(:b)).to eq(1)
  end

  describe "each" do
    it "should provide elements in order of the last modified" do
      counter = WebMock::Util::HashCounter.new
      counter.put(:a)
      counter.put(:b)
      counter.put(:c)
      counter.put(:b)
      counter.put(:a)
      counter.put(:d)

      elements = []
      counter.each {|k,v| elements << [k,v]}
      expect(elements).to eq([[:c, 1], [:b, 2], [:a, 2], [:d, 1]])
    end
  end
end
