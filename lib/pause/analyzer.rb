require 'pause/helper/timing'

module Pause
  class Analyzer
    include Pause::Helper::Timing

    attr_accessor :adapter

    def initialize
      @adapter ||= Pause::Redis::Adapter.new(Pause.config)
    end

    def increment(action, timestamp = Time.now.to_i, count = 1)
      adapter.increment(action.key, timestamp, count)
    end

    def check(action, &block)
      analyze(action, &block)
      !adapter.blocked?(action.key)
    end

    def tracked_identifiers(scope)
      adapter.all_keys(scope)
    end

    def blocked_identifiers(scope)
      adapter.blocked_keys(scope)
    end

    private

    def analyze(action, &block)
      timestamp = period_marker(Pause.config.resolution, Time.now.to_i)
      set = adapter.key_history(action.key)
      action.checks.each do |period_check|
        start_time = timestamp - period_check.period_seconds
        set.reverse.inject(0) do |sum, element|
          break if element.ts < start_time
          sum += element.count
          if sum >= period_check.max_allowed
            adapter.block(action.key, period_check.block_ttl)

            if block_given?
              return block.call(period_check, sum)
            end

            return true
          end
          sum
        end
      end
      nil
    end

  end
end
