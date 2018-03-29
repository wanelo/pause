module Pause
  class Logger
    def self.puts(message)
      STDOUT.puts message
    end

    def self.fatal(message)
      STDERR.puts message.red
    end
  end
end
