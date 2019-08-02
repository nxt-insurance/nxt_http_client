module NxtHttpClient
  module ClientDsl
    def configure(opts = {}, &block)
      @default_config ||= DefaultConfig.new(**opts)
      @default_config.tap { |d| block.call(d) }
      @default_config
    end

    def before_fire(&block)
      @before_fire_callback = block
    end

    def before_fire_callback
      @before_fire_callback
    end

    def after_fire(&block)
      @after_fire_callback = block
    end

    def after_fire_callback
      @after_fire_callback
    end

    def default_config
      @default_config ||= DefaultConfig.new
    end

    def register_response_handler(handler = nil, &block)
      @response_handler = handler
      @response_handler ||= dup_handler_from_ancestor_or_new
      @response_handler.configure(&block) if block_given?
      @response_handler
    end

    def response_handler
      @response_handler
    end

    def dup_handler_from_ancestor_or_new
      handler_from_ancestor = ancestors[1].instance_variable_get(:@response_handler)
      handler_from_ancestor && handler_from_ancestor.dup || NxtHttpClient::ResponseHandler.new
    end

    def inherited(child)
      child.instance_variable_set(:@response_handler, @response_handler.dup)
      child.instance_variable_set(:@before_fire_callback, @before_fire_callback.dup)
      child.instance_variable_set(:@after_fire_callback, @after_fire_callback.dup)
      child.instance_variable_set(:@default_config, DefaultConfig.new(**default_config.to_h.deep_dup))
    end
  end
end
