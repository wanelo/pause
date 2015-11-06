module Pause
  module Redis
    class OperationNotSupported < StandardError
    end

    # This class encapsulates Redis operations used by Pause.
    # Operations that are not possible when data is sharded
    # raise an error.
    class ShardedAdapter < Adapter
      def increment(scope, identifier, timestamp, count = 1)
        k = tracked_key(scope, identifier)
        redis.zincrby k, count, period_marker(resolution, timestamp)
        redis.expire k, history

        if redis.zcard(k) > time_blocks_to_keep
          list = extract_set_elements(k)
          to_remove = list.slice(0, (list.size - time_blocks_to_keep))
          redis.zrem(k, to_remove.map(&:ts))
        end
      end


      private

      def redis
        @redis_conn ||= ::Redis.new(host: Pause.config.redis_host,
          port: Pause.config.redis_port)
      end

      def keys(_key_scope)
        raise OperationNotSupported.new('Can not be executed when Pause is configured in sharded mode')
      end
    end
  end
end
