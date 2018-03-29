require 'spec_helper'
require 'date'
require 'timecop'

describe Pause::Redis::ShardedAdapter do

  let(:resolution) { 10 }
  let(:history) { 60 }
  let(:configuration) { Pause::Configuration.new }

  before do
    allow(Pause).to receive(:config).and_return(configuration)
    allow(Pause.config).to receive(:resolution).and_return(resolution)
    allow(Pause.config).to receive(:history).and_return(history)
  end

  let(:adapter) { Pause::Redis::ShardedAdapter.new(Pause.config) }

  describe '#all_keys' do
    it 'is not supported' do
      expect { adapter.all_keys('cake') }.to raise_error(Pause::Redis::OperationNotSupported)
    end
  end

  describe '#with_multi' do
    let(:redis) { adapter.send(:redis) }
    it 'should not call redis.multi' do
      expect(redis).to_not receive(:multi)
      expect { adapter.increment(:scope, 123, Time.now) }.to_not raise_error
    end
  end

  describe '#redis' do
    it 'should not use redis db when connecting' do
      expect(adapter.send(:redis_connection_opts)).to_not include(:db)
    end
  end
end
