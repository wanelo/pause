require 'spec_helper'
require 'date'
require 'timecop'

describe Pause::Redis::Adapter do

  let(:resolution) { 10 }
  let(:history) { 60 }
  let(:configuration) { Pause::Configuration.new }

  before do
    allow(Pause).to receive(:config).and_return(configuration)
    allow(Pause.config).to receive(:resolution).and_return(resolution)
    allow(Pause.config).to receive(:history).and_return(history)
    redis_conn.flushall
  end

  let(:adapter) { Pause::Redis::Adapter.new(Pause.config) }
  let(:redis_conn) { adapter.send(:redis) }

  describe '#increment' do
    let(:scope) { "blah" }
    let(:identifier) { "213213" }
    let(:tracked_key) { "i:blah:|213213|"}

    it "should add key to a redis set" do
      adapter.increment(scope, identifier, Time.now.to_i)
      set = redis_conn.zrange(tracked_key, 0, -1, :with_scores => true)
      expect(set).to_not be_empty
      expect(set.size).to eql(1)
      expect(set[0].size).to eql(2)
    end

    it "should remove old key from a redis set" do
      time = Time.now
      expect(redis_conn).to receive(:zrem).with(tracked_key, [adapter.period_marker(resolution, time)])

      adapter.time_blocks_to_keep = 1
      Timecop.freeze time do
        adapter.increment(scope, identifier, Time.now.to_i)
      end
      Timecop.freeze time + (adapter.resolution + 1) do
        adapter.increment(scope, identifier, Time.now.to_i)
      end
    end

    it "sets expiry on key" do
      expect(redis_conn).to receive(:expire).with(tracked_key, history)
      adapter.increment(scope, identifier, Time.now.to_i)
    end
  end

  describe '#expire_block_list' do
    let(:scope) { 'a' }
    let(:expired_identifier) { '123' }
    let(:blocked_identifier) { '124' }

    it 'clears all entries with score older than now' do
      now = Time.now

      Timecop.freeze now - 10 do
        adapter.rate_limit!(scope, expired_identifier, 5)
      end

      Timecop.freeze now - 4 do
        adapter.rate_limit!(scope, blocked_identifier, 5)
      end

      adapter.expire_block_list(scope)

      expect(redis_conn.zscore('b:|a|', blocked_identifier)).not_to be nil
      expect(redis_conn.zscore('b:|a|', expired_identifier)).to be nil
    end
  end

  describe "#rate_limit!" do
  end

  describe "#rate_limited?" do
    let(:scope) { 'ipn:follow' }
    let(:identifier) { '123461234' }
    let(:blocked_key) { "b:#{key}" }
    let(:ttl) { 110000 }

    it "should return true if blocked" do
      adapter.rate_limit!(scope, identifier, ttl)
      expect(adapter.rate_limited?(scope, identifier)).to be true
    end
  end

  describe "#tracked_key" do
    it "prefixes key" do
      expect(adapter.send(:tracked_key, "abc", "12345")).to eq("i:abc:|12345|")
    end
  end

  describe '#enable' do
    it 'deletes the disabled flag in redis' do
      adapter.disable("boom")
      expect(adapter.disabled?("boom")).to be true
      adapter.enable("boom")
      expect(adapter.disabled?("boom")).to be false
    end
  end

  describe '#disable' do
    it 'sets the disabled flag in redis' do
      expect(adapter.enabled?("boom")).to be true
      adapter.disable("boom")
      expect(adapter.enabled?("boom")).to be false
    end
  end

  describe '#rate_limit!' do
    it 'rate limits a key for a specific ttl' do
      expect(adapter.rate_limited?('blah', '1')).to be false
      adapter.rate_limit!('blah', '1', 10)
      expect(adapter.rate_limited?('blah', '1')).to be true
    end

    describe 'redis internals' do
      let(:scope) { 'ipn:follow' }
      let(:identifier) { '1234' }
      let(:blocked_key) { "b:|#{scope}|" }
      let(:ttl) { 110000 }

      it "saves ip to redis with expiration" do
        time = Time.now
        Timecop.freeze time do
          adapter.rate_limit!(scope, identifier, ttl)
        end
        expect(redis_conn.zscore(blocked_key, identifier)).to_not be nil
        expect(redis_conn.zscore(blocked_key, identifier)).to eq(time.to_i + ttl)
      end

    end
  end

  describe '#delete_rate_limited_keys' do
    it 'calls redis del with all keys' do
      adapter.rate_limit!('boom', '1', 10)
      adapter.rate_limit!('boom', '2', 10)

      expect(adapter.rate_limited?('boom', '1')).to be true
      expect(adapter.rate_limited?('boom', '2')).to be true

      adapter.delete_rate_limited_keys('boom')

      expect(adapter.rate_limited?('boom', '1')).to be false
      expect(adapter.rate_limited?('boom', '2')).to be false
    end
  end

  describe '#delete_rate_limit_key' do
    it 'calls redis del with all keys' do
      adapter.rate_limit!('boom', '1', 10)
      adapter.rate_limit!('boom', '2', 10)

      expect(adapter.rate_limited?('boom', '1')).to be true
      expect(adapter.rate_limited?('boom', '2')).to be true

      adapter.delete_rate_limited_key('boom', '1')

      expect(adapter.rate_limited?('boom', '1')).to be false
      expect(adapter.rate_limited?('boom', '2')).to be true
    end
  end
end
