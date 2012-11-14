require 'spec_helper'
require 'date'
require 'timecop'

describe Pause::Redis::Adapter do

  let(:resolution) { 10 }
  let(:history) { 60 }
  let(:configuration) { Pause::Configuration.new }

  before do
    Pause.stub(:config).and_return(configuration)
    Pause.config.stub(:resolution).and_return(resolution)
    Pause.config.stub(:history).and_return(history)
  end

  let(:adapter) { Pause::Redis::Adapter.new(Pause.config) }
  let(:redis_conn) { adapter.send(:redis) }

  describe '#increment' do
    let(:key) { "213213" }

    it "should add key to a redis set" do
      adapter.increment(key, Time.now.to_i)
      set = redis_conn.zrange(adapter.send(:white_key, key), 0, -1, :with_scores => true)
      set.should_not be_empty
      set.size.should eql(1)
      set[0].size.should eql(2)
    end

    it "should remove old key from a redis set" do
      time = Time.now
      redis_conn.should_receive(:zrem).with(adapter.send(:white_key, key), [adapter.period_marker(resolution, time)])

      adapter.time_blocks_to_keep = 1
      Timecop.freeze time do
        adapter.increment(key, Time.now.to_i)
      end
      Timecop.freeze time + (adapter.resolution + 1) do
        adapter.increment(key, Time.now.to_i)
      end
    end

    it "sets expiry on key" do
      redis_conn.should_receive(:expire).with(adapter.send(:white_key, key), history)
      adapter.increment(key, Time.now.to_i)
    end
  end

  describe "#block" do
    let(:key) { "ipn:follow:123461234" }
    let(:blocked_key) { "b:#{key}" }
    let(:ttl) { 110000 }

    it "saves ip to redis with expiration" do
      adapter.rate_limit!(key, ttl)
      redis_conn.get(blocked_key).should_not be_nil
      redis_conn.ttl(blocked_key).should == ttl
    end
  end

  describe "#blocked?" do
    let(:key) { "ipn:follow:123461234" }
    let(:blocked_key) { "b:#{key}" }
    let(:ttl) { 110000 }

    it "should return true if blocked" do
      adapter.rate_limit!(key, ttl)
      (!!redis_conn.get(blocked_key).should) == adapter.rate_limited?(key)
    end
  end

  describe "#white_key" do
    it "prefixes key" do
      adapter.send(:white_key, "abc").should == "i:abc"
    end
  end
end
