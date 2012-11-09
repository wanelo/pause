require 'spec_helper'
require 'timecop'

describe Rateable::Analyzer do
  include Rateable::Helper::Timing

  let(:resolution) { 10 }
  let(:history) { 60 }

  before do
    Rateable.stub(:redis).and_return(Redis.new)
    Rateable.config.stub(:resolution).and_return(resolution)
    Rateable.config.stub(:history).and_return(history)
    Rateable.stub(:adapter).and_return(Rateable::Redis::Adapter.new(Rateable.config))
  end

  let(:analyzer) { Rateable::Analyzer.new }
  let(:adapter) { Rateable.adapter }
  let(:config) {
    {
        analyzer: {period_checks: periods, block_timeout: 50, blocked_ip_notifiers: [ "Rateable::Notifier::Campfire" ]},
        collector: {resolution: 10, history: 100},
    }
  }
  let(:periods) {
    [
        {period_seconds: 10, max_allowed: 2, block_ttl: 20},
        {period_seconds: 30, max_allowed: 3, block_ttl: 20}
    ]
  }
  let (:period_structs) do
    [
        Rateable::PeriodCheck.new(10, 2, 20),
        Rateable::PeriodCheck.new(30, 3, 20)
    ]
  end

  let(:identifier) { "123" }
  let(:identifier2) { "123434" }

  let(:performed_action) {
    Rateable::Action.new(type: "ipn:follow", checks: periods).performed_action(identifier)
  }

  let(:performed_action2) {
      Rateable::Action.new(type: "ipn:follow", checks: periods).performed_action(identifier2)
  }

  context "#periods" do
    it "should properly assign periods" do
      performed_action.action.checks.should_not be_empty
      performed_action.action.checks.size.should eql(2)
      Rateable::PeriodCheck.from_action(performed_action.action).should eql(period_structs)
    end
  end

  describe "#analyze" do

    let(:now) { period_marker(10, Time.now.to_i) + 1 }

    context "IP count matches first period in list" do
      it "returns a blocked IP" do
        adapter.increment(performed_action.key, now - 5, 2)
        adapter.increment(performed_action.key, now - 15, 1)

        adapter.identifier_history(performed_action.key).should_not be_empty
        adapter.identifier_history(performed_action.key).size.should eql(2)

        analyzer.analyze(performed_action).should_not be_nil
        adapter.blocked?(performed_action.key).should be_true
      end
    end

    context "IP count matches later period" do
      it "returns a blocked IP" do
        adapter.increment(performed_action, now - 5, 1)
        adapter.increment(performed_action, now - 15, 2)

        adapter.identifier_history(performed_action).should_not be_empty
        adapter.identifier_history(performed_action).size.should eql(2)

        analyzer.analyze(performed_action).should_not be_nil
        adapter.blocked?(performed_action.key).should be_true
      end
    end

    context "IP count is just under threshold" do
      it "does not returns a blocked IP" do
        adapter.increment(performed_action, now - 5, 1)
        adapter.increment(performed_action, now - 15, 1)
        adapter.increment(performed_action, now - 35, 1)

        adapter.identifier_history(performed_action).should_not be_empty
        adapter.identifier_history(performed_action).size.should eql(3)

        analyzer.analyze(performed_action).should be_nil
      end
    end

    context "no period can be matched" do
      it "return nil" do
        analyzer.adapter.increment(performed_action, Time.now.to_i)
        analyzer.analyze(performed_action).should be_nil
      end
    end
  end
end
