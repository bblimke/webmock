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
