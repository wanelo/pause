require 'pause/helper/timing'

module Pause
  class Analyzer
    include Pause::Helper::Timing

    attr_accessor :adapter

    def initialize
      @adapter ||= Pause::Redis::Adapter.new(Pause.config)
    end

    def increment(action, timestamp = Time.now.to_i)
      adapter.increment(action.key, timestamp)
      analyze(action)
    end

    def check(action)
      !adapter.blocked?(action.key)
    end

    private

    def analyze(action)
      timestamp = period_marker(Pause.config.resolution, Time.now.to_i)
      set = adapter.key_history(action.key)
      Pause.config.checks[action.scope].each do |period_check|
        start_time = timestamp - period_check.period_seconds
        set.reverse.inject(0) do |sum, element|
          break if element.ts < start_time
          sum += element.count
          if sum >= period_check.max_allowed
            adapter.block(action.key, period_check.block_ttl)
            return true
          end
          sum
        end
      end
      nil
    end

  end
end
