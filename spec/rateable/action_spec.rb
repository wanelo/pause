require 'spec_helper'
require 'date'
require 'timecop'

describe Rateable::Action do

  before do
    Rateable.stub(:redis).and_return(Redis.new)

    Rateable.config.stub(:history).and_return(60)
    Rateable.config.stub(:resolution).and_return(10)
  end

  let(:type) { "hellos:said" }
  let(:checks) {
    [
        {period_seconds: 10, max_allowed: 2, block_ttl: 20},
        {period_seconds: 30, max_allowed: 3, block_ttl: 20}
    ]
  }

  let(:action) { Rateable::Action.new({ type: type, checks: checks }) }
  let(:identifier) { 123 }
  let(:performed_action) { Rateable::PerformedAction.new(identifier, action) }

  describe "#increment!" do
    it "increments the count for the given identifier" do
      Timecop.freeze Time.now.to_i - 5 do
        action.increment!(identifier)
      end

      Timecop.freeze Time.now.to_i - 2 do
        action.increment!(identifier)
      end

      action.increment!(identifier)

      action.ok?(identifier).should eq(false)
    end
  end

  describe "#ok?" do

  end
end
