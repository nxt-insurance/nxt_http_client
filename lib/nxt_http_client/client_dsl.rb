module NxtHttpClient
  module ClientDsl
    def configure(opts = {}, &block)
      opts.each { |k, v| config.send(k, v) }
      config.tap { |d| block.call(d) }
      config
    end

    def clear_fire_callbacks(*kinds)
      callbacks.clear(*kinds)
    end

    def before_fire(&block)
      callbacks.register(:before, block)
    end

    def after_fire(&block)
      callbacks.register(:after, block)
    end

    def around_fire(&block)
      callbacks.register(:around, block)
    end

    def config
      @config ||= dup_option_from_ancestor(:@config) { DefaultConfig.new }
    end

    def callbacks
      @callbacks ||= dup_option_from_ancestor(:@callbacks) { FireCallbacks.new }
    end

    def response_handler(handler = Undefined.new, &block)
      if undefined?(handler)
        @response_handler ||= dup_option_from_ancestor(:@response_handler) { NxtHttpClient::ResponseHandler.new }
      else
        @response_handler = handler
      end

      @response_handler.configure(&block) if block_given?
      @response_handler
    end

    alias_method :response_handler, :response_handler

    def client_ancestors
      ancestors.select { |ancestor| ancestor <= NxtHttpClient::Client }
    end

    def option_from_ancestors(instance_variable_name)
      client = client_ancestors.find { |c| c.instance_variable_get(instance_variable_name) }
      client && client.instance_variable_get(instance_variable_name)
    end

    def dup_option_from_ancestor(instance_variable_name)
      result = option_from_ancestors(instance_variable_name).dup
      return result unless block_given?

      result || yield
    end

    def undefined?(value)
      value.is_a?(Undefined)
    end
  end
end
