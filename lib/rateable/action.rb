module Rateable
  class Action
    attr_accessor :type, :checks

    def initialize(options)
      @type = options[:type]
      @checks = options[:checks]
    end

    def performed_action(identifier)
      PerformedAction.new(identifier, self)
    end

    def increment!(identifier)
      Rateable.analyzer.increment(performed_action(identifier))
    end

    def ok?(identifier)
      Rateable.adapter.blocked?(performed_action(identifier).key)
    end

    def period_checks
      PeriodCheck.from_action(self)
    end

  end
end
