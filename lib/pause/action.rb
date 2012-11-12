module Pause
  class Action
    attr_accessor :identifier

    def initialize(identifier)
      @identifier = identifier
      self.class.instance_variable_set(:@checks, []) unless self.class.instance_variable_get(:@checks)
    end

    # Action subclasses should define their scope as follows
    #
    #     class MyAction < Pause::Action
    #       scope "my:scope"
    #     end
    #
    def scope
      raise "Should implement scope. (Ex: ipn:follow)"
    end

    def self.scope(scope_identifier = nil)
      define_method(:scope) { scope_identifier }
    end

    # Action subclasses should define their checks as follows
    #
    #  period_seconds - compare all activity by an identifier within the time period
    #  max_allowed - if the number of actions by an identifier exceeds max_allowed for the time period marked
    #                by period_seconds, it is no longer ok.
    #  ttl - time to mark identifier as not ok
    #
    #     class MyAction < Pause::Action
    #       check 10, 20, 30 # period_seconds, max_allowed, ttl
    #       check 20, 30, 40 # period_seconds, max_allowed, ttl
    #     end
    #
    def self.check(period_seconds, max_allowed, block_ttl)
      @checks ||= []
      @checks << PeriodCheck.new(period_seconds, max_allowed, block_ttl)
    end

    def checks
      self.class.instance_variable_get(:@checks)
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
