require 'spec_helper'
require 'timecop'

describe Pause::Action do
  include Pause::Helper::Timing

  class MyNotification < Pause::Action
    scope "ipn:follow"
    check 20, 5, 40
    check 40, 7, 40
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
      time = period_marker(resolution, Time.now.to_i + 1)

      Timecop.freeze Time.at(time - 35) do
        4.times do
          action.increment!
          action.ok?.should be_true
        end
      end

      Timecop.freeze Time.at(time - 5) do
        2.times do
          action.increment!
          action.ok?.should be_true
        end
        action.increment!
        action.ok?.should be_false
      end
    end

    context "action is disabled" do

      it "should be true if action is disabled, even if blocked" do
        10.times { action.increment! }
        action.ok?.should be_false

        MyNotification.disable

        action.ok?.should be_true
      end
    end
  end

  describe "#analyze" do
    context "action should not be blocked" do
      it "returns nil" do
        action.analyze.should be_nil
      end
    end

    context "action should be blocked" do
      it "returns a BlockedAction object" do
        time = Time.now
        blocked_action = nil

        Timecop.freeze time do
          7.times { action.increment! }
          blocked_action = action.analyze
        end

        expected_blocked_action = Pause::BlockedAction.new(action, action.checks[0], 7, time.to_i)

        blocked_action.should be_a(Pause::BlockedAction)
        blocked_action.identifier.should == expected_blocked_action.identifier
        blocked_action.sum.should == expected_blocked_action.sum
        blocked_action.period_check.should == expected_blocked_action.period_check
        blocked_action.timestamp.should == expected_blocked_action.timestamp
      end
    end

    context "action is disabled" do
      it "return nil, even if blocked" do
        10.times { action.increment! }
        action.should_not be_ok

        MyNotification.disable

        action.analyze.should be_nil
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

  describe "#blocked_identifiers" do
    it "should return all the identifiers blocked" do
      action.increment!(Time.now.to_i, 100)
      other_action.increment!(Time.now.to_i, 100)

      action.ok?
      other_action.ok?

      MyNotification.blocked_identifiers.should include(action.identifier)
      MyNotification.blocked_identifiers.should include(other_action.identifier)
    end
  end

  describe "#unblock_all" do
    it "should unblock all the identifiers for a scope" do
      10.times { action.increment! }
      other_action.increment!

      action.ok?
      other_action.ok?

      MyNotification.tracked_identifiers.should include(action.identifier, other_action.identifier)
      MyNotification.blocked_identifiers.should == [action.identifier]

      MyNotification.unblock_all

      MyNotification.blocked_identifiers.should be_empty
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

  it "should define a period check on new instances" do
    ActionWithCheck.new("id").checks.should == [
        Pause::PeriodCheck.new(100, 150, 200),
    ]
  end

  it "should define a period check on new instances" do
    ActionWithMultipleChecks.new("id").checks.should == [
        Pause::PeriodCheck.new(100, 150, 200),
        Pause::PeriodCheck.new(200, 150, 200),
        Pause::PeriodCheck.new(300, 150, 200)
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
