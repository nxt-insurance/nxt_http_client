module NxtHttpClient
  class Callbacks
    def initialize
      @registry = build_registry
    end

    attr_reader :registry

    def register(kind, callback)
      registry.resolve!(kind) << callback
    end

    def run(target, kind, *args)
      registry.resolve!(kind).each do |callback|
        run_callback(target, callback, *args)
      end
    end

    def around(type, *args, &execution)
      around_callbacks = registry.resolve!(:around, type)
      return execution.call unless around_callbacks.any?

      callback_chain = around_callbacks.reverse.inject(execution) do |previous, callback|
        -> { callback.call(*args, previous) }
      end

      callback_chain.call
    end

    private

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
