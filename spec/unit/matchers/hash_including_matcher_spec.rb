require 'spec_helper'

module WebMock
  module Matchers

    describe HashIncludingMatcher do

      it "stringifies the given hash keys" do
        expect(HashIncludingMatcher.new(:a => 1, :b => 2)).to eq("a" => 1, "b" => 2)
      end

      it "sorts elements in the hash" do
        expect(HashIncludingMatcher.new(:b => 2, :a => 1)).to eq("a" => 1, "b" => 2)
      end

      it "describes itself properly" do
        expect(HashIncludingMatcher.new(:a => 1).inspect).to eq "hash_including({\"a\"=>1})"
      end

      describe "success" do
        it "matches the same hash" do
          expect(HashIncludingMatcher.new("a" => 1, "b" => 2)).to eq("a" => 1, "b" => 2)
        end

        it "matches a hash with extra stuff" do
          expect(HashIncludingMatcher.new(:a => 1)).to eq("a" => 1, "b" => 2)
        end

        describe "when matching anythingized keys" do
          let(:anything) { WebMock::Matchers::AnyArgMatcher.new(nil) }

          it "matches an int against anything()" do
            expect(HashIncludingMatcher.new(:a => anything, :b => 2)).to eq({'a' => 1, 'b' => 2})
          end

          it "matches a string against anything()" do
            expect(HashIncludingMatcher.new(:a => anything, :b => 2)).to eq({'a' => "1", 'b' => 2})
          end

          it "matches if the key is present" do
            expect(HashIncludingMatcher.new(:a => anything)).to eq({'a' => 1, 'b' => 2})
          end

          it "matches if more keys are present" do
            expect(HashIncludingMatcher.new(:a => anything, :b => anything)).to eq({'a' => 1, 'b' => 2, 'c' => 3})
          end

          it "matches if passed many keys and many key/value pairs" do
            expect(HashIncludingMatcher.new(:a => anything, :b => anything, :c => 3, :e => 5)).to eq({'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4, 'e' => 5})
          end
        end

        describe "when matching an empty hash" do
          it "matches against any hash" do
            expect(HashIncludingMatcher.new({})).to eq({:a => 1, :b => 2, :c => 3})
          end
        end
      end

      describe "failing" do
        it "does not match a non-hash" do
          expect(HashIncludingMatcher.new(:a => 1)).not_to eq 1
        end

        it "does not match a hash with a missing key" do
          expect(HashIncludingMatcher.new(:a => 1)).not_to eq('b' => 2)
        end

        it "does not match an empty hash with a given key" do
          expect(HashIncludingMatcher.new(:a => 1)).not_to eq({})
        end

        it "does not match a hash with a missing key when one pair is matching" do
          expect(HashIncludingMatcher.new(:a => 1, :b => 2)).not_to eq('b' => 2)
        end

        it "does not match a hash with an incorrect value" do
          expect(HashIncludingMatcher.new(:a => 1, :b => 2)).not_to eq('a' => 1, 'b' => 3)
        end

        it "does not match when values are nil but keys are different" do
          expect(HashIncludingMatcher.new(:a => nil)).not_to eq('b' => nil)
        end
      end
    end
  end
end
