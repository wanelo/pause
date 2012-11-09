require "rateable/version"
require "rateable/configuration"
require "rateable/action"
require "rateable/analyzer"
require "rateable/redis/adapter"

module Rateable

  class PerformedAction < Struct.new(:identifier, :action)
    def key
      "#{action.type}:#{identifier}"
    end
  end

  class PeriodCheck < Struct.new(:period_seconds, :max_allowed, :block_ttl)
    def <=>(other)
      self.period_seconds <=> other.period_seconds
    end

    def self.from_action(action)
      @periods ||= action.checks.map do |check|
        self.new(check[:period_seconds], check[:max_allowed], check[:block_ttl])
      end
    end
  end

  class SetElement < Struct.new(:ts, :count)
    def <=>(other)
      self.ts <=> other.ts
    end
  end

  class << self
    def redis
      @redis ||= ::Redis.new(host: config.redis_host, port: config.redis_port, db: config.redis_db)
    end

    def analyzer
      @analyzer ||= Rateable::Analyzer.new
    end

    def adapter
      @adapter ||= Rateable::Redis::Adapter.new(config)
    end

    def actions
      config.actions
    end

    def configure(&block)
      Rateable::Configuration.configure(&block)
    end

    def config
      Rateable::Configuration
    end
  end
end

#Ratable.configure do |config|
#  config.redis_host = "123123123"
#
#  config.resolution = 300
#  config.history = 21600
#
#  config.actions = [
#      {
#          type: "follow:ipn",
#          checks: [
#            { period_seconds: 3600, max_allowed: 2000, block_ttl: 7200 }
#          ]
#      }
#  ]
#end
#
#if Rateable.actions["follow:ipn"].ok?(123)
#  # send push notification
#  Rateable.actions["follow:ipn"].increment!(123)
#end
