require 'spec_helper'
require 'timecop'

describe Pause::Analyzer do
  include Pause::Helper::Timing

  class FollowPushNotification < Pause::Action
    scope "ipn:follow"
    check 20, 5, 12
    check 40, 7, 12
  end

  let(:resolution) { 10 }
  let(:history) { 60 }
  let(:configuration) { Pause::Configuration.new }

  before do
    Pause.stub(:config).and_return(configuration)
    Pause.config.stub(:resolution).and_return(resolution)
    Pause.config.stub(:history).and_return(history)
  end

  let(:analyzer) { Pause.analyzer }
  let(:adapter) { Pause.analyzer.adapter }
  let(:action) { FollowPushNotification.new("1243123") }

  describe "#increment" do
    it "should increment an action" do
      time = Time.now
      adapter.should_receive(:increment).with(action.key, time.to_i)
      analyzer.should_receive(:analyze).with(action)
      Timecop.freeze time do
        analyzer.increment(action)
      end
    end
  end

  describe "#analyze" do
    it "checks and blocks if max_allowed is reached" do
      time = Time.now
      adapter.should_receive(:block).once.with(action.key, 12)
      Timecop.freeze time do
        5.times do
          analyzer.increment(action)
        end
      end
    end
  end

  describe "#check" do
    it "should return true if action is NOT blocked" do
      analyzer.check(action).should be_true
    end

    it "should return false if action is blocked" do
      Timecop.freeze Time.now do
        5.times do
          analyzer.increment(action)
        end
        analyzer.check(action).should be_false
      end
    end
  end
end
