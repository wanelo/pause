module Pause
  class Action
    attr_accessor :identifier

    def initialize(identifier)
      @identifier = identifier
    end

    def self.scope
      raise "Should implement scope. (Ex: ipn:follow)"
    end

    def scope
      self.class.scope
    end

    def increment!
      Pause.analyzer.increment(self)
    end

    def ok?
      Pause.analyzer.check(self)
    end

    def key
      "#{self.scope}:#{@identifier}"
    end
  end
end
