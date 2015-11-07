require 'spec_helper'
require 'timecop'

describe Pause::Analyzer do
  include Pause::Helper::Timing

  class FollowPushNotification < Pause::Action
    scope 'ipn:follow'
    check 20, 5, 12
    check 40, 7, 12
  end

  let(:resolution) { 10 }
  let(:history) { 60 }
  let(:configuration) { Pause::Configuration.new }
  let(:adapter) { Pause::Redis::Adapter.new(configuration) }

  before do
    allow(Pause).to receive(:config).and_return(configuration)
    allow(Pause.config).to receive(:resolution).and_return(resolution)
    allow(Pause.config).to receive(:history).and_return(history)
    allow(Pause).to receive(:adapter).and_return(adapter)
  end

  let(:analyzer) { Pause.analyzer }
  let(:action) { FollowPushNotification.new('1243123') }

  describe '#analyze' do
    it 'checks and blocks if max_allowed is reached' do
      time = Time.now
      expect(adapter).to receive(:rate_limit!).once.with(action.scope, '1243123', 12)
      Timecop.freeze time do
        5.times do
          action.increment!
          analyzer.check(action)
        end
      end
    end
  end

  describe '#check' do
    it 'should return nil if action is NOT blocked' do
      expect(analyzer.check(action)).to be nil
    end

    it 'should return blocked action if action is blocked' do
      Timecop.freeze Time.now do
        5.times do
          action.increment!
        end
        expect(analyzer.check(action)).to be_a(Pause::RateLimitedEvent)
      end
    end
  end
end
