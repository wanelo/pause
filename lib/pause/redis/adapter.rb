require 'pause/helper/timing'

module Pause
  module Redis

    # This class encapsulates Redis operations used by Pause
    class Adapter
      class << self
        def redis
          @redis_conn ||= ::Redis.new(redis_connection_opts)
        end

        def redis_connection_opts
          { host: Pause.config.redis_host,
            port: Pause.config.redis_port,
            db:   Pause.config.redis_db }
        end
      end

      include Pause::Helper::Timing
      attr_accessor :resolution, :time_blocks_to_keep, :history

      def initialize(config)
        @resolution          = config.resolution
        @time_blocks_to_keep = config.history / @resolution
        @history             = config.history
      end

      # Override in subclasses to disable
      def with_multi
        redis.multi do |redis|
          yield(redis) if block_given?
        end
      end

      def increment(scope, identifier, timestamp, count = 1)
        k = tracked_key(scope, identifier)
        with_multi do |redis|
          redis.zincrby k, count, period_marker(resolution, timestamp)
          redis.expire k, history
        end

        truncate_set_for(k)
      end

      def key_history(scope, identifier)
        extract_set_elements(tracked_key(scope, identifier))
      end

      def rate_limit!(scope, identifier, block_ttl)
        timestamp = Time.now.to_i + block_ttl
        redis.zadd rate_limited_list(scope), timestamp, identifier
        expire_block_list(scope)
      end

      def rate_limited?(scope, identifier)
        blocked_until = redis.zscore(rate_limited_list(scope), identifier)
        !!blocked_until && blocked_until > Time.now.to_i
      end

      def all_keys(scope)
        keys(tracked_scope(scope))
      end

      def rate_limited_keys(scope)
        redis.zrangebyscore rate_limited_list(scope), Time.now.to_i, '+inf'
      end

      # For a scope, delete the entire sorted set that holds the block list.
      # Also delete the original tracking information, so we don't immediately re-block the id
      #
      # @return count [Integer] the number of items deleted
      def delete_rate_limited_keys(scope)
        return 0 unless rate_limited_keys(scope).any?
        delete_tracking_keys(scope, rate_limited_keys(scope))
        redis.zremrangebyscore(rate_limited_list(scope), '-inf', '+inf').tap do |_count|
          redis.del rate_limited_list(scope)
        end
      end

      def delete_rate_limited_key(scope, id)
        delete_tracking_keys(scope, [id])
        redis.zrem rate_limited_list(scope), id
      end

      def disable(scope)
        redis.set("internal:|#{scope}|:disabled", "1")
      end

      def enable(scope)
        redis.del("internal:|#{scope}|:disabled")
      end

      def disabled?(scope)
        !enabled?(scope)
      end

      def enabled?(scope)
        redis.get("internal:|#{scope}|:disabled").nil?
      end

      def expire_block_list(scope)
        redis.zremrangebyscore rate_limited_list(scope), '-inf', Time.now.to_i
      end

      private

      def redis
        self.class.redis
      end

      def truncate_set_for(k)
        if redis.zcard(k) > time_blocks_to_keep
          list      = extract_set_elements(k)
          to_remove = list.slice(0, (list.size - time_blocks_to_keep)).map(&:ts)
          redis.zrem(k, to_remove) if k && to_remove && to_remove.size > 0
        end
      end

      def delete_tracking_keys(scope, ids)
        increment_keys = ids.map { |key| tracked_key(scope, key) }
        redis.del(increment_keys)
      end

      def tracked_scope(scope)
        ['i', scope].join(':')
      end

      def tracked_key(scope, identifier)
        id = "|#{identifier}|"
        [tracked_scope(scope), id].join(':')
      end

      def rate_limited_list(scope)
        "b:|#{scope}|"
      end

      def keys(key_scope)
        redis.keys("#{key_scope}:*").map do |key|
          key.gsub(/^#{key_scope}:/, "").tr('|', '')
        end
      end

      def extract_set_elements(key)
        (redis.zrange key, 0, -1, with_scores: true).map do |slice|
          Pause::SetElement.new(slice[0].to_i, slice[1].to_i)
        end.sort
      end
    end
  end
end
