module Pause
  class RateLimitedEvent
    attr_accessor :action, :identifier, :period_check, :sum, :timestamp

    def initialize(action, period_check, sum, timestamp)
      @action = action
      @identifier = action.identifier
      @period_check = period_check
      @sum = sum
      @timestamp = timestamp
    end

  end
end
