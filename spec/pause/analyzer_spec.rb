require 'spec_helper'
require 'timecop'

describe Pause::Analyzer do
  include Pause::Helper::Timing

  class FollowPushNotification < Pause::Action
    scope "ipn:follow"
    check 20, 5, 12
    check 40, 7, 12
  end

  class UberSimpleCheck < Pause::Action
    scope "usc"
    check period_seconds: 10, max_allowed: 3
  end

  let(:resolution) { 1 }
  let(:history) { 60 }
  let(:configuration) { Pause::Configuration.new }

  before do
    allow(Pause).to receive(:config).and_return(configuration)
    allow(Pause.config).to receive(:resolution).and_return(resolution)
    allow(Pause.config).to receive(:history).and_return(history)
  end

  let(:analyzer) { Pause.analyzer }
  let(:adapter) { Pause.adapter }
  let(:action) { FollowPushNotification.new("1243123") }

  describe "#analyze" do
    it "checks and blocks if max_allowed is reached" do
      time = Time.now
      adapter.should_receive(:rate_limit!).once.with(action.key, 12)
      Timecop.freeze time do
        5.times do
          action.increment!
          analyzer.check(action)
        end
      end
    end

    context "checks without block_ttl" do
      let(:action) { UberSimpleCheck.new("1243123") }

      it "blocks only for the amount of time until an action would be allowed again" do
        adapter.should_receive(:rate_limit!).once.with(action.key, 3)

        now = Time.now.to_i

        Timecop.freeze now - 10 do
          action.increment!
        end

        Timecop.freeze now - 5 do
          action.increment!
        end

        Timecop.freeze now - 3 do
          action.increment!
        end

        Timecop.freeze now do
          analyzer.check(action)
        end
      end
    end

    context "with a set element with a higher count" do
      let(:action) { UberSimpleCheck.new("1243123") }

      it "blocks for a period appropriate to when the limit was exceeded" do
        adapter.should_receive(:rate_limit!).once.with(action.key, 5)

        now = Time.now.to_i

        Timecop.freeze now - 10 do
          action.increment!
        end

        Timecop.freeze now - 5 do
          action.increment!(2)
        end

        Timecop.freeze now - 3 do
          action.increment!
        end

        Timecop.freeze now do
          analyzer.check(action)
        end
      end
    end
  end

  describe "#check" do
    it "should return nil if action is NOT blocked" do
      analyzer.check(action).should be_nil
    end

    it "should return blocked action if action is blocked" do
      Timecop.freeze Time.now do
        5.times do
          action.increment!
        end
        analyzer.check(action).should be_a(Pause::RateLimitedEvent)
      end
    end
  end
end
