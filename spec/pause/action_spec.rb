require 'spec_helper'
require 'timecop'

describe Pause::Action do
  include Pause::Helper::Timing

  class MyNotification < Pause::Action
    scope "ipn:follow"
    check period_seconds: 20, max_allowed: 5, block_ttl: 40
    check period_seconds: 40, max_allowed: 7, block_ttl: 40
  end

  let(:resolution) { 10 }
  let(:history) { 60 }
  let(:configuration) { Pause::Configuration.new }

  before do
    Pause.stub(:config).and_return(configuration)
    Pause.config.stub(:resolution).and_return(resolution)
    Pause.config.stub(:history).and_return(history)
  end

  let(:action) { MyNotification.new("1237612") }
  let(:other_action) { MyNotification.new("1237613") }

  describe "#increment!" do
    it "should increment" do
      time = Time.now
      Timecop.freeze time do
        Pause.analyzer.should_receive(:increment).with(action, time.to_i, 1)
        action.increment!
      end
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
      time = period_marker(resolution, Time.now.to_i)

      action.increment! 4, time - 25
      action.ok?.should be_true

      action.increment! 2, time - 3
      action.ok?.should be_true

      action.increment! 1, time

      action.ok?.should be_false

    end

    it "should return false and silently fail if redis is not available" do
      Redis.any_instance.stub(:zrange) { raise Redis::CannotConnectError }
      time = period_marker(resolution, Time.now.to_i)

      action.increment! 4, time - 25

      action.ok?.should be_false
    end
  end

  describe "#analyze" do
    context "action should not be rate limited" do
      it "returns nil" do
        action.analyze.should be_nil
      end
    end

    context "action should be rate limited" do
      it "returns a RateLimitedEvent object" do
        time = Time.now
        rate_limit = nil

        Timecop.freeze time do
          7.times { action.increment! }
          rate_limit = action.analyze
        end

        expected_rate_limit = Pause::RateLimitedEvent.new(action, action.checks[0], 7, time.to_i)

        rate_limit.should be_a(Pause::RateLimitedEvent)
        rate_limit.identifier.should == expected_rate_limit.identifier
        rate_limit.sum.should == expected_rate_limit.sum
        rate_limit.period_check.should == expected_rate_limit.period_check
        rate_limit.timestamp.should == expected_rate_limit.timestamp
      end
    end
  end

  describe "#tracked_identifiers" do
    it "should return all the identifiers tracked (but not blocked) so far" do
      action.increment!
      other_action.increment!

      action.ok?
      other_action.ok?

      MyNotification.tracked_identifiers.should include(action.identifier)
      MyNotification.tracked_identifiers.should include(other_action.identifier)
    end
  end

  describe "#rate_limited_identifiers" do
    it "should return all the identifiers blocked" do
      action.increment!(100, Time.now.to_i)
      other_action.increment!(100, Time.now.to_i)

      action.ok?
      other_action.ok?

      MyNotification.rate_limited_identifiers.should include(action.identifier)
      MyNotification.rate_limited_identifiers.should include(other_action.identifier)
    end
  end

  describe "#unblock_all" do
    it "should unblock all the identifiers for a scope" do
      10.times { action.increment! }
      other_action.increment!

      action.ok?
      other_action.ok?

      MyNotification.tracked_identifiers.should include(action.identifier, other_action.identifier)
      MyNotification.rate_limited_identifiers.should == [action.identifier]

      MyNotification.unblock_all

      MyNotification.rate_limited_identifiers.should be_empty
      MyNotification.tracked_identifiers.should == [other_action.identifier]
    end
  end
end

describe Pause::Action, ".check" do
  class ActionWithCheck < Pause::Action
    check 100, 150, 200
  end

  class ActionWithMultipleChecks < Pause::Action
    check 100, 150, 200
    check 200, 150, 200
    check 300, 150, 200
  end

  class ActionWithHashChecks < Pause::Action
    check period_seconds: 50, block_ttl: 60, max_allowed: 100
  end

  it "should define a period check on new instances" do
    ActionWithCheck.new("id").checks.should == [
        Pause::PeriodCheck.new(100, 150, 200)
    ]
  end

  it "should define a period check on new instances" do
    ActionWithMultipleChecks.new("id").checks.should == [
        Pause::PeriodCheck.new(100, 150, 200),
        Pause::PeriodCheck.new(200, 150, 200),
        Pause::PeriodCheck.new(300, 150, 200)
    ]
  end

  it "should accept hash arguments" do
    ActionWithHashChecks.new("id").checks.should == [
        Pause::PeriodCheck.new(50, 100, 60)
    ]
  end

end

describe Pause::Action, ".scope" do
  class UndefinedScopeAction < Pause::Action
  end

  it "should raise if scope is not defined" do
    lambda {
      UndefinedScopeAction.new("1.2.3.4").scope
    }.should raise_error("Should implement scope. (Ex: ipn:follow)")
  end

  class DefinedScopeAction < Pause::Action
    scope "my:scope"
  end

  it "should set scope on class" do
    DefinedScopeAction.new("1.2.3.4").scope.should == "my:scope"
  end
end

describe Pause::Action, "enabled/disabled states" do
  class BlockedAction < Pause::Action
    scope "blocked"
    check 10, 0, 10
  end

  before do
    Pause.configure do |c|
      c.resolution = 10
      c.history = 10
    end
  end

  let(:action) { BlockedAction }

  describe "#disable" do
    before do
      action.should be_enabled
      action.should_not be_disabled
      action.disable
    end

    it "disables the action" do
      action.should be_disabled
      action.should_not be_enabled
    end
  end

  describe "#enable" do
    before do
      action.disable
      action.should_not be_enabled
      action.enable
    end

    it "enables the action" do
      action.should be_enabled
      action.should_not be_disabled
    end
  end
end
