module Pause
  class Action
    attr_accessor :identifier

    def initialize(identifier, &block)
      @identifier       = identifier
      self.class.checks ||= []
      instance_exec(&block) if block
    end

    def scope
      self.class.scope
    end

    class << self
      attr_accessor :checks

      def inherited(klass)
        klass.instance_eval do
          # Action subclasses should define their scope as follows
          #
          #     class MyAction < Pause::Action
          #       scope "my:scope"
          #     end
          #
          @scope = klass.name.downcase.gsub(/::/, '.')
          class << self

            # @param [String] args
            def scope(*args)
              @scope = args.first if args && args.size == 1
              @scope
            end
          end
        end
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
      def enable
        adapter.enable(scope)
      end

      def disable
        adapter.disable(scope)
      end

      def enabled?
        adapter.enabled?(scope)
      end

      def disabled?
        !enabled?
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
      def check(*args, **opts)
        self.checks ||= []

        params =
          if args.empty?
            # if block_ttl is not provided, just default to the period
            opts[:block_ttl] ||= opts[:period_seconds]
            [opts[:period_seconds], opts[:max_allowed], opts[:block_ttl]]
          else
            args
          end

        self.checks << Pause::PeriodCheck.new(*params)
      end

      def tracked_identifiers
        adapter.all_keys(scope)
      end

      def rate_limited_identifiers
        adapter.rate_limited_keys(scope)
      end

      def unblock_all
        adapter.delete_rate_limited_keys(scope)
      end

      def adapter
        Pause.adapter
      end
    end

    def unless_rate_limited(count: 1, timestamp: Time.now.to_i, &_block)
      check_result = analyze
      if check_result.nil?
        yield
        increment!(count, timestamp)
      else
        check_result
      end
    end

    def if_rate_limited(&_block)
      check_result = analyze(recalculate: true)
      yield(check_result) unless check_result.nil?
    end

    def checks
      self.class.checks
    end

    def block_for(ttl)
      adapter.rate_limit!(scope, identifier, ttl)
    end

    def increment!(count = 1, timestamp = Time.now.to_i)
      adapter.increment(scope, identifier, timestamp, count)
    end

    def rate_limited?
      !ok?
    end

    def ok?
      Pause.analyzer.check(self).nil?
    rescue ::Redis::CannotConnectError => e
      Pause::Logger.fatal "Error connecting to redis: #{e.inspect} #{e.message} #{e.backtrace.join("\n")}"
      false
    end

    def analyze(recalculate: false)
      Pause.analyzer.check(self, recalculate: recalculate)
    end

    def unblock
      adapter.delete_rate_limited_key(scope, identifier)
    end

    private

    def adapter
      self.class.adapter
    end

  end
end
