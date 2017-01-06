module Pause
  module Redis
    class OperationNotSupported < StandardError
    end

    # This class encapsulates Redis operations used by Pause.
    # Operations that are not possible when data is sharded
    # raise an error.
    class ShardedAdapter < Adapter

      # Overrides real multi which is not possible when sharded.
      def with_multi
        yield(redis) if block_given?
      end

      protected

      def redis_connection_opts
        { host: Pause.config.redis_host,
          port: Pause.config.redis_port }
      end

      private

      def keys(_key_scope)
        raise OperationNotSupported.new('Can not be executed when Pause is configured in sharded mode')
      end
    end
  end
end
