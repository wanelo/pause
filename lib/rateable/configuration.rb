module Rateable
  module Configuration
    class << self
      attr_reader :redis_host, :redis_port, :redis_db, :actions, :resolution, :history

      def configure
        yield self
      end

      def actions=(values)
        @actions = {}
        values.each do |value|
          action = Rateable::Action.new(value)
          @actions[action.type] = action
        end
      end
    end
  end
end
