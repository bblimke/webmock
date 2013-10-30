require 'spec_helper'

describe WebMock::API do
  describe '#hash_including' do
    context 'when mixed into a class that does not define `hash_including`' do
      subject do
        Class.new do
          include WebMock::API
        end.new
      end

      it 'uses WebMock::Matchers::HashIncludingMatcher' do
        expect(subject.hash_including(:foo, :bar)).to be_a(WebMock::Matchers::HashIncludingMatcher)
      end
    end

    context 'when mixed into a class that defines `hash_including`' do
      subject do
        Class.new do
          def hash_including(*args)
            args
          end

          include WebMock::API
        end.new
      end

      it 'uses super and passes the args untampered' do
        expect(subject.hash_including(:foo, :bar)).to be_a(Array)
      end
    end
  end
end
