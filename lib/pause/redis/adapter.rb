require 'pause/helper/timing'

module Pause
  module Redis

    # This class encapsulates Redis operations used by Pause
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

      def rate_limit!(key, block_ttl)
        redis.setex(rate_limited_key(key), block_ttl, nil)
      end

      def rate_limited?(key)
        !!redis.get(rate_limited_key(key))
      end

      def all_keys(scope)
        keys(white_key(scope))
      end

      def rate_limited_keys(scope)
        keys(rate_limited_key(scope))
      end

      def delete_rate_limited_keys(scope)
        delete_rate_limited_ids scope, rate_limited_keys(scope)
      end

      def delete_rate_limited_key(scope, id)
        delete_rate_limited_ids scope, [id]
      end

      def disable(scope)
        redis.set("disabled:#{scope}", "1")
      end

      def enable(scope)
        redis.del("disabled:#{scope}")
      end

      def disabled?(scope)
        ! enabled?(scope)
      end

      def enabled?(scope)
        redis.keys("disabled:#{scope}").first.nil?
      end

      private

      def delete_rate_limited_ids(scope, ids)
        increment_keys = ids.map{ |key| white_key(scope, key) }
        rate_limited_keys = ids.map{ |key| rate_limited_key(scope, key) }
        redis.del(increment_keys + rate_limited_keys)
      end

      def redis
        @redis_conn ||= ::Redis.new(host: Pause.config.redis_host,
                                    port: Pause.config.redis_port,
                                    db:   Pause.config.redis_db)
      end

      def white_key(scope, key = nil)
        ["i", scope, key].compact.join(':')
      end

      def rate_limited_key(scope, key = nil)
        ["b", scope, key].compact.join(':')
      end

      def keys(key_scope)
        redis.keys("#{key_scope}:*").map do |key|
          key.gsub(/^#{key_scope}:/, "")
        end
      end

      def extract_set_elements(key)
        (redis.zrange key, 0, -1, :with_scores => true).map do |slice|
          Pause::SetElement.new(slice[0].to_i, slice[1].to_i)
        end.sort
      end
    end
  end
end
