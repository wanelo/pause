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
    #  max_allowed    - if the number of actions by an identifier exceeds max_allowed for the time period marked
    #                   by period_seconds, it is no longer ok.
    #  block_ttl      - time to mark identifier as not ok
    #
    #     class MyAction < Pause::Action
    #       check period_seconds: 60,   max_allowed: 100,  block_ttl: 3600
    #       check period_seconds: 1800, max_allowed: 2000, block_ttl: 3600
    #     end
    #
    def self.check(*args)
      @checks ||= []
      period_seconds, max_allowed, block_ttl =
        if args.first.is_a?(Hash)
          [args.first[:period_seconds], args.first[:max_allowed], args.first[:block_ttl]]
        else
          args
        end
      @checks << Pause::PeriodCheck.new(period_seconds, max_allowed, block_ttl)
    end

    def self.checks
      @checks
    end

    def checks
      self.class.checks
    end

    def self.checks=(period_checks)
      @checks = period_checks
    end

    def increment!(count = 1, timestamp = Time.now.to_i)
      adapter.increment(key, timestamp, count)
    end

    def rate_limited?
      ! ok?
    end

    def ok?
      !Pause.adapter.rate_limited?(key) && Pause.analyzer.check(self).nil?
    rescue ::Redis::CannotConnectError => e
      $stderr.puts "Error connecting to redis: #{e.inspect}"
      false
    end

    def analyze
      Pause.analyzer.check(self)
    end

    def self.tracked_identifiers
      adapter.all_keys(self.class_scope)
    end

    def self.rate_limited_identifiers
      adapter.rate_limited_keys(self.class_scope)
    end

    def self.unblock_all
      adapter.delete_rate_limited_keys(self.class_scope)
    end

    def unblock
      adapter.delete_rate_limited_key(scope, identifier)
    end

    def key
      "#{self.scope}:#{identifier}"
    end

    # Actions can be globally disabled or re-enabled in a persistent
    # way.
    #
    #   MyAction.disable
    #   MyAction.enabled? => false
    #   MyAction.disabled? => true
    #
    #   MyAction.enable
    #   MyAction.enabled? => true
    #   MyAction.disabled? => false
    #
    def self.enable
      adapter.enable(class_scope)
    end

    def self.disable
      adapter.disable(class_scope)
    end

    def self.enabled?
      adapter.enabled?(class_scope)
    end

    def self.disabled?
      ! enabled?
    end

    private

    def self.adapter
      Pause.adapter
    end

    def adapter
      self.class.adapter
    end

    def self.class_scope
      class_variable_get:@@class_scope if class_variable_defined?(:@@class_scope)
    end
  end
end
