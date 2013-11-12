require 'spec_helper'

describe WebMock::API do
  describe '#hash_including' do

    subject { klass.new.hash_including(args) }
    let(:args) { {:data => :one} }

    context 'when mixed into a class that does not define `hash_including`' do
      let(:klass) do
        Class.new do
          include WebMock::API
        end
      end

      it 'uses WebMock::Matchers::HashIncludingMatcher' do
        expect(subject).to be_a(WebMock::Matchers::HashIncludingMatcher)
      end

      #  by testing equality for HashIncludingMatcher (which stringifies the passed hash) we are
      #  testing HashIncludingMatcher.initialize behavior as well
      context "when args correspond to an hash" do
        it "creates 'HashIncludingMatcher'" do
          expect(subject).to eq("data" => :one)
        end
      end

      context "when args are one or many keys" do
        subject {klass.new.hash_including(:foo, :bar)}
        let(:anything) { WebMock::Matchers::AnyArgMatcher.new(nil) }

        it "creates 'HashIncludingMatcher' with keys anythingized" do
          expect(subject).to eq("foo" => anything, "bar" => anything )
        end
      end

      context "when args are both keys and key/value pairs" do
        subject {klass.new.hash_including(:foo, :bar, :data => :one)}
        let(:anything) { WebMock::Matchers::AnyArgMatcher.new(nil) }

        it "creates 'HashIncludingMatcher' with keys anythingized" do
          expect(subject).to eq("foo" => anything, "bar" => anything, "data" => :one)
        end
      end

      context "when args are an emtpy hash" do
        subject {klass.new.hash_including({})}

        it "creates 'HashIncludingMatcher' with an empty hash" do
          expect(subject).to eq({})
        end
      end
    end


    context 'when mixed into a class with a parent that defines `hash_including`' do
      subject {klass.new.hash_including(*args)}
      let(:args) { %w(:foo, :bar, {:data => :one}) }
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