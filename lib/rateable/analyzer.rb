require 'rateable/helper/timing'

module Rateable
  class Analyzer
    include Rateable::Helper::Timing

    attr_accessor :adapter, :periods

    def initialize
      @adapter = Rateable.adapter
    end

    # Analyze individual IP for all defined periods.  As soon as one
    # rule is triggered, exit the method
    def increment(performed_action, timestamp = Time.now.to_i)
      adapter.increment(performed_action.key, timestamp)
      analyze(performed_action)
    end

    def analyze(performed_action)
      timestamp = period_marker(Rateable.config.resolution, Time.now.to_i)
      set = adapter.identifier_history(performed_action.key)
      puts "set: #{set.inspect}"
      action = performed_action.action
      action.period_checks.each do |period|
        start_time = timestamp - period.period_seconds
        set.reverse.inject(0) do |sum, element|
          break if element.ts < start_time
          sum += element.count
          if sum >= period.max_allowed
            adapter.block(performed_action.key, period.block_ttl)
            puts performed_action.key
            puts period.block_ttl.inspect
            puts "blocked?: #{adapter.blocked?(performed_action.key).inspect}"
            return true
          end
          sum
        end
      end
      nil
    end

  end
end
