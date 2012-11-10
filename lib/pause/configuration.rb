module Pause
  module Configuration
    class << self
      attr_reader :redis_host, :redis_port, :redis_db, :checks, :resolution, :history

      def configure
        yield self
      end

    end
  end
end
