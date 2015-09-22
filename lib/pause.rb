require 'redis'
require 'pause/version'
require 'pause/configuration'
require 'pause/action'
require 'pause/analyzer'
require 'pause/logger'
require 'pause/redis/adapter'
require 'pause/redis/sharded_adapter'
require 'pause/rate_limited_event'

module Pause
  class PeriodCheck < Struct.new(:period_seconds, :max_allowed, :block_ttl)
    def <=>(other)
      self.period_seconds <=> other.period_seconds
    end
  end

  class SetElement < Struct.new(:ts, :count)
    def <=>(other)
      self.ts <=> other.ts
    end
  end

  class << self
    def analyzer
      @analyzer ||= Pause::Analyzer.new
    end

    def adapter
      @adapter ||= config.sharded ?
        Pause::Redis::ShardedAdapter.new(config) :
        Pause::Redis::Adapter.new(config)
    end

    def adapter=(adapter)
      @adapter = adapter
    end

    def configure(&block)
      @configuration = Pause::Configuration.new.configure(&block)
    end

    def config
      @configuration
    end
  end
end
