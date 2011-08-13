require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe WebMock::HttpLibAdapterRegistry do
  describe "each_adapter" do
    it "should yield block over each adapter" do
      class MyAdapter < WebMock::HttpLibAdapter; end
      WebMock::HttpLibAdapterRegistry.instance.http_lib_adapters = {
        :my_lib => MyAdapter
      }
      adapters = []
      WebMock::HttpLibAdapterRegistry.instance.each_adapter {|n,a|
        adapters << [n, a]
      }
      adapters.should == [[:my_lib, MyAdapter]]
    end
  end
end