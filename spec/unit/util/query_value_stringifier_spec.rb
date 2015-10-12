require "spec_helper"

RSpec.describe WebMock::Util::QueryValueStringifier do
  describe ".stringify" do
    it "handles strings" do
      expect(described_class.stringify("a")).to eq("a")
    end

    it "handles integers" do
      expect(described_class.stringify(1)).to eq("1")
    end

    it "handles booleans" do
      expect(described_class.stringify(true)).to eq("true")
    end

    it "handles symbols" do
      expect(described_class.stringify(:hello)).to eq("hello")
    end

    it "handles hashes" do
      input = { :a => :a, :b => :b, :c => 1, :d => [true, false] }
      expect(described_class.stringify(input)).to eq(
        { :a => "a", :b => "b", :c => "1", :d => ["true", "false"] }
      )
    end

    it "handles arrays" do
      input = [ :a, 1, [true, false], {"a" => :b} ]
      expect(described_class.stringify(input)).to eq(
        [ "a", "1", ["true", "false"], {"a" => "b"} ]
      )
    end
  end
end
