require 'spec_helper'

describe WebMock::API do
  describe '#hash_including' do
    subject { klass.new.hash_including(*args) }

    let(:args) { %w(foo bar) }

    context 'when mixed into a class that does not define `hash_including`' do
      let(:klass) do
        Class.new do
          include WebMock::API
        end
      end

      it 'uses WebMock::Matchers::HashIncludingMatcher' do
        expect(subject).to be_a(WebMock::Matchers::HashIncludingMatcher)
      end
    end

    context 'when mixed into a class with a parent that defines `hash_including`' do
      let(:klass) do
        Class.new(
          Class.new do
            def hash_including(*args)
              args
            end
          end
        ) { include WebMock::API }
      end

      it 'uses super and passes the args untampered' do
        expect(subject).to eq(args)
      end
    end
  end
end
