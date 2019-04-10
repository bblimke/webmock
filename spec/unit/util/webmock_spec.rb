require 'spec_helper'

module WebMock
  describe ".net_connect_allowed?" do
    context 'enabled globally' do
      before do
        WebMock.enable_net_connect!
      end

      context 'without arguments' do
        it 'returns WebMock::Config.instance.allow_net_connect' do
          expect(WebMock.net_connect_allowed?).to be_truthy
        end
      end
    end

    context 'disabled with allowed remote string' do
      before do
        WebMock.disable_net_connect!(allow: "http://192.168.64.2:20031")
      end

      context 'without arguments' do
        it 'returns WebMock::Config.instance.allow_net_connect' do
          expect(WebMock.net_connect_allowed?).to be_falsey
        end
      end
    end

    context 'disabled globally' do
      before do
        WebMock.disable_net_connect!
      end

      context 'without arguments' do
        it 'returns WebMock::Config.instance.allow_net_connect' do
          expect(WebMock.net_connect_allowed?).to be_falsey
        end
      end
    end
  end
end
