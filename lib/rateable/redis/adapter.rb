require 'rateable/helper/timing'

module Rateable
  module Redis
    class Adapter

      include Rateable::Helper::Timing
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

      def identifier_history(key)
        extract_set_elements(white_key(key))
      end

      def block(key, block_ttl)
        puts "blocking: #{key}"
        redis.setex(blocked_key(key), block_ttl, nil)
      end

      def blocked?(key)
        !redis.get(blocked_key(key))
      end

      private

      def redis
        Rateable.redis
      end

      def get(key)
        extract_set_elements(key)
      end

      def white_key(identifier)
        "i:#{identifier}"
      end

      def blocked_key(identifier)
        "b:#{identifier}"
      end

      def extract_set_elements(key)
        (redis.zrange key, 0, -1, :with_scores => true).map do |slice|
          Rateable::SetElement.new(slice[0].to_i, slice[1].to_i)
        end.sort
      end
    end
  end
end
