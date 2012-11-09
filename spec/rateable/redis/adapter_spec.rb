require 'spec_helper'
require 'date'
require 'timecop'

describe Rateable::Redis::Adapter do

  let(:resolution) { 10 }
  let(:history) { 60 }

  before do
    Rateable.stub(:redis).and_return(Redis.new)
    Rateable.config.stub(:resolution).and_return(resolution)
    Rateable.config.stub(:history).and_return(history)
  end

  let(:adapter) { Rateable::Redis::Adapter.new(Rateable.config) }
  let(:redis) { Rateable.redis }

  describe '#increment' do
    let(:identifier) { "ipn:follow:213" }

    it "should add IP to a redis set" do
      adapter.increment(identifier, Time.now.to_i)
      set = redis.zrange(adapter.send(:white_key, identifier), 0, -1, :with_scores => true)
      set.should_not be_empty
      set.size.should eql(1)
      set[0].size.should eql(2)
    end

    it "should remove old IP from a redis set" do
      time = Time.now
      redis.should_receive(:zrem).with(adapter.send(:white_key, identifier), [adapter.period_marker(resolution, time)])

      adapter.time_blocks_to_keep = 1
      Timecop.freeze time do
        adapter.increment(identifier, Time.now.to_i)
      end
      Timecop.freeze time + (adapter.resolution + 1) do
        adapter.increment(identifier, Time.now.to_i)
      end
    end

    it "sets expiry on IP key" do
      redis.should_receive(:expire).with(adapter.send(:white_key, identifier), history)
      adapter.increment(identifier, Time.now.to_i)
    end
  end

  describe '#block_ip'  do
    let(:id) { "192.168.0.1" }
    let(:key) { "b:#{id}" }
    let(:ttl) { 110000 }

    it "saves ip to redis with expiration" do
      adapter.block(id, ttl)
      redis.get(key).should_not be_nil
      redis.ttl(key).should == ttl
    end
  end

  describe "#key" do
    it "prefixes IP" do
      adapter.send(:white_key, "abc").should == "i:abc"
    end
  end
end
