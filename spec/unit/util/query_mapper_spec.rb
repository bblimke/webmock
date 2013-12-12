require 'spec_helper'

describe WebMock::Util::QueryMapper do
  it "should parse hash queries" do
    # {"one" => {"two" => {"three" => ["four", "five"]}}}
    query = "one%5Btwo%5D%5Bthree%5D%5B%5D=four&one%5Btwo%5D%5Bthree%5D%5B%5D=five"
    hsh = WebMock::Util::QueryMapper.query_to_values(query)
    hsh["one"]["two"]["three"].should == ["four", "five"]
  end

  it "should parse one nil value queries" do
    # {'a' => nil, 'b' => 'c'}
    query = "a=&b=c"
    hsh = WebMock::Util::QueryMapper.query_to_values(query)
    hsh['a'].should be_empty
    hsh['b'].should == 'c'
  end

  it "should parse array queries" do
    # {"one" => ["foo", "bar"]}
    query = "one%5B%5D=foo&one%5B%5D=bar"
    hsh = WebMock::Util::QueryMapper.query_to_values(query)
    hsh["one"].should == ["foo", "bar"]
  end

  it "should parse string queries" do
    # {"one" => "two", "three" => "four"}
    query = "one=two&three=four"
    hsh = WebMock::Util::QueryMapper.query_to_values(query)
    hsh.should == {"one" => "two", "three" => "four"}
  end

  it "should parse nested queries" do
    # [{"b"=>[{"c"=>[{"d"=>["1", {"e"=>"2"}]}]}]}]
    query = "a%5B%5D%5Bb%5D%5B%5D%5Bc%5D%5B%5D%5Bd%5D%5B%5D=1&a%5B%5D%5Bb%5D%5B%5D%5Bc%5D%5B%5D%5Bd%5D%5B%5D%5Be%5D=2"
    hsh = WebMock::Util::QueryMapper.query_to_values(query)
    hsh["a"][0]["b"][0]["c"][0]["d"][0].should == "1"
    hsh["a"][0]["b"][0]["c"][0]["d"][1]["e"].should == "2"
  end

end
