require 'spec_helper'
require 'timecop'

describe Pause::Action do
  include Pause::Helper::Timing

  class MyNotification < Pause::Action
    scope 'ipn:follow'
    check period_seconds: 20, max_allowed: 5, block_ttl: 40
    check period_seconds: 40, max_allowed: 7, block_ttl: 40
  end

  let(:resolution) { 10 }
  let(:history) { 60 }
  let(:configuration) { Pause::Configuration.new }

  before do
    allow(Pause).to receive(:config).and_return(configuration)
    allow(Pause.config).to receive(:resolution).and_return(resolution)
    allow(Pause.config).to receive(:history).and_return(history)
    allow(Pause).to receive(:adapter).and_return(Pause::Redis::Adapter.new(Pause.config))
  end

  let(:action) { MyNotification.new('1237612') }
  let(:other_action) { MyNotification.new('1237613') }

  describe '#increment!' do
    it 'should increment' do
      time = Time.now
      Timecop.freeze time do
        expect(Pause.adapter).to receive(:increment).with(action.scope, '1237612', time.to_i, 1)
        action.increment!
      end
    end
  end

  describe '#ok?' do
    it 'should successfully return if the action is blocked or not' do
      time = Time.now
      Timecop.freeze time do
        4.times do
          action.increment!
          expect(action.ok?).to be true
        end
        action.increment!
        expect(action.ok?).to be false
      end
    end

    it 'should successfully consider different period checks' do
      time = Time.parse('Sept 22, 11:34:00')

      Timecop.freeze time - 30 do
        action.increment! 4
        expect(action.ok?).to be true
      end

      Timecop.freeze time do
        action.increment! 2
        expect(action.ok?).to be true
      end

      Timecop.freeze time do
        action.increment! 1
        expect(action.ok?).to be false
      end
    end

    it 'should return false and silently fail if redis is not available' do
      allow(Pause::Logger).to receive(:fatal)
      allow_any_instance_of(Redis).to receive(:zrange).and_raise Redis::CannotConnectError
      time = period_marker(resolution, Time.now.to_i)

      action.increment! 4, time - 25

      expect(action.ok?).to be false
    end
  end

  describe '#analyze' do
    context 'action should not be rate limited' do
      it 'returns nil' do
        expect(action.analyze).to be nil
      end
    end

    context 'action should be rate limited' do
      it 'returns a RateLimitedEvent object' do
        time = Time.now
        rate_limit = nil

        Timecop.freeze time do
          7.times { action.increment! }
          rate_limit = action.analyze
        end

        expected_rate_limit = Pause::RateLimitedEvent.new(action, action.checks[0], 7, time.to_i)

        expect(rate_limit).to be_a(Pause::RateLimitedEvent)
        expect(rate_limit.identifier).to eq(expected_rate_limit.identifier)
        expect(rate_limit.sum).to eq(expected_rate_limit.sum)
        expect(rate_limit.period_check).to eq(expected_rate_limit.period_check)
        expect(rate_limit.timestamp).to eq(expected_rate_limit.timestamp)
      end
    end
  end

  describe '.tracked_identifiers' do
    it 'should return all the identifiers tracked (but not blocked) so far' do
      action.increment!
      other_action.increment!

      action.ok?
      other_action.ok?

      expect(MyNotification.tracked_identifiers).to include(action.identifier)
      expect(MyNotification.tracked_identifiers).to include(other_action.identifier)
    end
  end

  describe '.rate_limited_identifiers' do
    it 'should return all the identifiers blocked' do
      action.increment!(100, Time.now.to_i)
      other_action.increment!(100, Time.now.to_i)

      action.ok?
      other_action.ok?

      expect(MyNotification.rate_limited_identifiers).to include(action.identifier)
      expect(MyNotification.rate_limited_identifiers).to include(other_action.identifier)
    end
  end

  describe '.unblock_all' do
    it 'should unblock all the identifiers for a scope' do
      10.times { action.increment! }
      other_action.increment!

      action.ok?
      other_action.ok?

      expect(MyNotification.tracked_identifiers).to include(action.identifier, other_action.identifier)
      expect(MyNotification.rate_limited_identifiers).to eq([action.identifier])

      MyNotification.unblock_all

      expect(MyNotification.rate_limited_identifiers).to be_empty
      expect(MyNotification.tracked_identifiers).to eq([other_action.identifier])
    end
  end

  describe '#unblock' do
    it 'unblocks the specified id' do
      10.times { action.increment! }

      expect(action.ok?).to be false

      action.unblock

      expect(action.ok?).to be true
    end
  end
end

describe Pause::Action, '.check' do
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

  it 'should define a period check on new instances' do
    expect(ActionWithCheck.new('id').checks).to eq([
          Pause::PeriodCheck.new(100, 150, 200)
        ])
  end

  it 'should define a period check on new instances' do
    expect(ActionWithMultipleChecks.new('id').checks).to eq([
          Pause::PeriodCheck.new(100, 150, 200),
          Pause::PeriodCheck.new(200, 150, 200),
          Pause::PeriodCheck.new(300, 150, 200)
        ])
  end

  it 'should accept hash arguments' do
    expect(ActionWithHashChecks.new('id').checks).to eq([
          Pause::PeriodCheck.new(50, 100, 60)
        ])
  end

end

describe Pause::Action, '.scope' do
  class UndefinedScopeAction < Pause::Action
  end

  it 'should raise if scope is not defined' do
    expect {
      UndefinedScopeAction.new('1.2.3.4').scope
    }.to raise_error('Should implement scope. (Ex: ipn:follow)')
  end

  class DefinedScopeAction < Pause::Action
    scope 'my:scope'
  end

  it 'should set scope on class' do
    expect(DefinedScopeAction.new('1.2.3.4').scope).to eq('my:scope')
  end
end

describe Pause::Action, 'enabled/disabled states' do
  class BlockedAction < Pause::Action
    scope 'blocked'
    check 10, 0, 10
  end

  before do
    Pause.configure do |c|
      c.resolution = 10
      c.history = 10
    end
  end

  let(:action) { BlockedAction }

  describe '#disable' do
    before do
      expect(action).to be_enabled
      expect(action).to_not be_disabled
      action.disable
    end

    it 'disables the action' do
      expect(action).to be_disabled
      expect(action).to_not be_enabled
    end
  end

  describe '#enable' do
    before do
      action.disable
      expect(action).to_not be_enabled
      action.enable
    end

    it 'enables the action' do
      expect(action).to be_enabled
      expect(action).to_not be_disabled
    end
  end
end
