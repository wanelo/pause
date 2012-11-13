module Pause
  class Action
    attr_accessor :identifier

    def initialize(identifier)
      @identifier = identifier
      self.class.checks = [] unless self.class.instance_variable_get(:@checks)
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
      class_variable_set(:@@class_scope, scope_identifier)
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
      @checks << Pause::PeriodCheck.new(period_seconds, max_allowed, block_ttl)
    end

    def checks
      self.class.instance_variable_get(:@checks)
    end

    def self.checks=(period_checks)
      @checks = period_checks
    end

    def increment!(timestamp = Time.now.to_i, count = 1)
      Pause.analyzer.increment(self, timestamp, count)
    end

    def ok?
      Pause.analyzer.check(self).nil?
    end

    def analyze
      Pause.analyzer.check(self)
    end

    def self.tracked_identifiers
      Pause.analyzer.tracked_identifiers(self.class_scope)
    end

    def self.blocked_identifiers
      Pause.analyzer.blocked_identifiers(self.class_scope)
    end

    def self.unblock_all
      Pause.analyzer.adapter.delete_keys(self.class_scope)
    end

    def key
      "#{self.scope}:#{@identifier}"
    end

    private

    def self.class_scope
      class_variable_get:@@class_scope if class_variable_defined?(:@@class_scope)
    end
  end
end
