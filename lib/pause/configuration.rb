module Pause
  class Configuration
    attr_writer :redis_host, :redis_port, :redis_db, :resolution, :history

    def configure
      yield self
    end

    def redis_host
      @redis_host || "127.0.0.1"
    end

    def redis_port
      (@redis_port || 6379).to_i
    end

    def redis_db
      @redis_db || '1'
    end

    def resolution
      (@resolution || 600).to_i
    end

    def history
      (@history || 86400).to_i
    end
  end
end
