require 'spec_helper'

RSpec.describe Pause do
  describe 'adapter' do
    let(:configuration) { Pause::Configuration.new }

    before do
      Pause.adapter = nil
      allow(Pause).to receive(:config).and_return(configuration)
      configuration.configure { |c| c.sharded = sharded }
    end

    context 'pause is sharded' do
      let(:sharded) { true }

      it 'is a ShardedAdapter' do
        expect(Pause.adapter).to be_a(Pause::Redis::ShardedAdapter)
      end
    end

    context 'pause is not sharded' do
      let(:sharded) { false }

      it 'is an Adapter' do
        expect(Pause.adapter).to be_a(Pause::Redis::Adapter)
      end
    end
  end
end
