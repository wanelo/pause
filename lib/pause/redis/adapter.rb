require 'pause/helper/timing'

module Pause
  module Redis
    class Adapter

      include Pause::Helper::Timing
      attr_accessor :resolution, :time_blocks_to_keep, :history

      def initialize(config)
        @resolution = config.resolution
        @time_blocks_to_keep = config.history / @resolution
        @history = config.history
      end

      def increment(key, timestamp, count = 1)
        k = white_key(key)
        redis.multi do |redis|
          redis.zincrby k, count, period_marker(resolution, timestamp)
          redis.expire k, history
        end

        if redis.zcard(k) > time_blocks_to_keep
          list = extract_set_elements(k)
          to_remove = list.slice(0, (list.size - time_blocks_to_keep))
          redis.zrem(k, to_remove.map(&:ts))
        end
      end

      def key_history(key)
        extract_set_elements(white_key(key))
      end

      def block(key, block_ttl)
        redis.setex(blocked_key(key), block_ttl, nil)
      end

      def blocked?(key)
        !!redis.get(blocked_key(key))
      end

      private

      def redis
        @redis_conn ||= ::Redis.new(host: Pause.config.redis_host,
                                    port: Pause.config.redis_port,
                                    db:   Pause.config.redis_db)
      end

      def white_key(key)
        "i:#{key}"
      end

      def blocked_key(key)
        "b:#{key}"
      end

      def extract_set_elements(key)
        (redis.zrange key, 0, -1, :with_scores => true).map do |slice|
          Pause::SetElement.new(slice[0].to_i, slice[1].to_i)
        end.sort
      end
    end
  end
end
