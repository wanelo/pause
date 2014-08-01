require 'pause/helper/timing'

module Pause
  class Analyzer
    include Pause::Helper::Timing

    class BlockTTLChecker < Struct.new(:period_check, :timestamp, :set, :action)
      def check
        start_time = timestamp - period_check.period_seconds
        set.reverse.inject(0) do |sum, element|
          break if element.ts < start_time
          sum += element.count
          if sum >= period_check.max_allowed
            Pause.adapter.rate_limit!(action.key, period_check.block_ttl)
            # Note that Time.now is different from period_marker(resolution, Time.now), which
            # rounds down to the nearest (resolution) seconds
            return Pause::RateLimitedEvent.new(action, period_check, sum, Time.now.to_i)
          end
          sum
        end
        nil
      end
    end

    class PeriodTTLChecker < Struct.new(:period_check, :timestamp, :set, :action)
      def check
        start_time = timestamp - period_check.period_seconds
        set.select!{|element| element.ts >= start_time}
        set.inject(0) do |sum, element|
          sum += element.count
          if sum >= period_check.max_allowed
            block_ttl = set.first.ts + period_check.period_seconds - element.ts
            Pause.adapter.rate_limit!(action.key, block_ttl)
            # Note that Time.now is different from period_marker(resolution, Time.now), which
            # rounds down to the nearest (resolution) seconds
            return Pause::RateLimitedEvent.new(action, period_check, sum, Time.now.to_i)
          end
          sum
        end
        nil
      end
    end

    def check(action)
      timestamp = period_marker(Pause.config.resolution, Time.now.to_i)
      set = Pause.adapter.key_history(action.key)
      action.checks.each do |period_check|
        checker = if period_check.block_ttl
                    BlockTTLChecker.new(period_check, timestamp, set, action)
                  else
                    PeriodTTLChecker.new(period_check, timestamp, set, action)
                  end

        puts checker.inspect
        result = checker.check
        return result if result
      end
      nil
    end
  end
end
