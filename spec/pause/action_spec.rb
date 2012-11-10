require 'spec_helper'
require 'timecop'

describe Pause::Action do
  include Pause::Helper::Timing

  class FollowPushNotification < Pause::Action
    def self.scope
      "ipn:follow"
    end
  end

  let(:resolution) { 10 }
  let(:history) { 60 }
  let(:checks) {
    {
      FollowPushNotification.scope => [Pause::PeriodCheck.new(20, 5, 50),
                                       Pause::PeriodCheck.new(40, 7, 50)]
    }
  }

  before do
    Pause.config.stub(:resolution).and_return(resolution)
    Pause.config.stub(:history).and_return(history)
    Pause.config.stub(:checks).and_return(checks)
  end

  let(:action) { FollowPushNotification.new("1237612") }

  describe "#increment!" do
    it "should increment" do
      Pause.analyzer.should_receive(:increment).with(action)
      action.increment!
    end
  end

  describe "#ok?" do
    it "should successfully return if the action is blocked or not" do
      time = Time.now
      Timecop.freeze time do
        4.times do
          action.increment!
          action.ok?.should be_true
        end
        action.increment!
        action.ok?.should be_false
      end
    end

    it "should successfully consider different period checks" do
      time = Time.now
      Timecop.freeze time do
        4.times do
          action.increment!
          action.ok?.should be_true
        end
      end
      Timecop.freeze Time.at(time.to_i + 30) do
        2.times do
          action.increment!
          action.ok?.should be_true
        end
        action.increment!
        action.ok?.should be_false
      end
    end
  end
end
