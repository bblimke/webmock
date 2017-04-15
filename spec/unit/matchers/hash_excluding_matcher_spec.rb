require 'spec_helper'

module WebMock
  module Matchers
    describe HashExcludingMatcher do
      it 'stringifies the given hash keys' do
        expect(HashExcludingMatcher.new(a: 1, b: 2)).not_to eq('a' => 1, 'b' => 2)
      end

      it 'sorts elements in the hash' do
        expect(HashExcludingMatcher.new(b: 2, a: 1)).not_to eq('a' => 1, 'b' => 2)
      end

      it 'describes itself properly' do
        expect(HashExcludingMatcher.new(a: 1).inspect).to eq 'hash_excluding({"a"=>1})'
      end

      describe 'success' do
        it 'match with hash with a missing key' do
          expect(HashExcludingMatcher.new(a: 1)).to eq('b' => 2)
        end

        it 'match an empty hash with a given key' do
          expect(HashExcludingMatcher.new(a: 1)).to eq({})
        end

        it 'match when values are nil but keys are different' do
          expect(HashExcludingMatcher.new(a: nil)).to eq('b' => nil)
        end

        describe 'when matching an empty hash' do
          it 'does not matches against any hash' do
            expect(HashExcludingMatcher.new({})).to eq(a: 1, b: 2, c: 3)
          end
        end
      end

      describe 'failing' do
        it 'does not match a hash with a one missing key when one pair is matching' do
          expect(HashExcludingMatcher.new(a: 1, b: 2)).not_to eq('b' => 2)
        end

        it 'match a hash with an incorrect value' do
          expect(HashExcludingMatcher.new(a: 1, b: 2)).not_to eq('a' => 1, 'b' => 3)
        end

        it 'does not matches the same hash' do
          expect(HashExcludingMatcher.new('a' => 1, 'b' => 2)).not_to eq('a' => 1, 'b' => 2)
        end

        it 'does not matches a hash with extra stuff' do
          expect(HashExcludingMatcher.new(a: 1)).not_to eq('a' => 1, 'b' => 2)
        end

        it 'does not match a non-hash' do
          expect(HashExcludingMatcher.new(a: 1)).not_to eq 1
        end
      end
    end
  end
end
