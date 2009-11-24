require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Util::HashCounter do

  it "should return 0 for non existing key" do
    Util::HashCounter.new.get(:abc).should == 0
  end

  it "should increase the returned value on every put with the same key" do
    counter =Util::HashCounter.new
    counter.put(:abc)
    counter.get(:abc).should == 1
    counter.put(:abc)
    counter.get(:abc).should == 2
  end

  it "should only increase value for given key provided to put" do
    counter =Util::HashCounter.new
    counter.put(:abc)
    counter.get(:abc).should == 1
    counter.get(:def).should == 0
  end

end
