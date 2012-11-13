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
