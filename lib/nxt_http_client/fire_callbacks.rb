module NxtHttpClient
  class FireCallbacks
    def initialize
      @registry = build_registry
    end

    def clear(*kinds)
      Array(kinds).each { |kind| registry.register!(kind, []) }
    end

    def register(kind, callback)
      registry.resolve!(kind) << callback
    end

    def run(target, kind, *args)
      registry.resolve!(kind).each do |callback|
        run_callback(target, callback, *args)
      end
    end

    def run_before(target:, request:, response_handler:)
      registry.resolve!(:before).each do |callback|
        run_callback(target, callback, *[target, request, response_handler])
      end
    end

    def run_after(target:, request:, response:, result:, error:)
      registry.resolve!(:after).inject(result) do |_, callback|
        run_callback(target, callback, *[target, request, response, result, error])
      end
    end

    def any_around_callbacks?
      registry.resolve(:around).any?
    end

    def any_after_callbacks?
      registry.resolve(:after).any?
    end

    def run_around(target:, request:, response_handler:, fire:)
      around_callbacks = registry.resolve!(:around)
      return fire.call unless around_callbacks.any?

      args = *[target, request, response_handler]
      callback_chain = around_callbacks.reverse.inject(fire) do |previous, callback|
        -> { target.instance_exec(*args, previous, &callback) }
      end

      callback_chain.call
    end

    def initialize_copy(original)
      @registry = original.instance_variable_get(:@registry).clone
      super
    end

    private

    attr_reader :registry

    def run_callback(target, callback, *args)
      args = args.take(callback.arity)
      target.instance_exec(*args, &callback)
    end

    def build_registry
      NxtRegistry::Registry.new(:callbacks) do
        register(:before, [])
        register(:around, [])
        register(:after, [])
      end
    end
  end
end
