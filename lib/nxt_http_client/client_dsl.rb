module NxtHttpClient
  module ClientDsl
    def configure(opts = {}, &block)
      opts.each do |k,v|
        default_config.send(k, v)
      end
      default_config.tap { |d| block.call(d) }
      default_config
    end

    def before_fire(&block)
      @before_fire_callback = block
    end

    def before_fire_callback
      @before_fire ||= dup_instance_variable_from_ancestor_chain(:@before_fire_callback)
    end

    def after_fire(&block)
      @after_fire_callback = block
    end

    def after_fire_callback
      @after_fire_callback ||= dup_instance_variable_from_ancestor_chain(:@after_fire_callback)
    end

    def default_config
      @default_config ||= dup_instance_variable_from_ancestor_chain(:@default_config) { DefaultConfig.new }
    end

    def register_response_handler(handler = nil, &block)
      @response_handler = handler
      @response_handler ||= dup_instance_variable_from_ancestor_chain(:@response_handler) { NxtHttpClient::ResponseHandler.new }
      @response_handler.configure(&block) if block_given?
      @response_handler
    end

    def response_handler
      @response_handler ||= dup_instance_variable_from_ancestor_chain(:@response_handler) { NxtHttpClient::ResponseHandler.new }
    end

    def client_ancestors
      ancestors.select { |ancestor| ancestor <= NxtHttpClient::Client }
    end

    def instance_variable_from_ancestor_chain(instance_variable_name)
      client = client_ancestors.find do |client|
        client.instance_variable_get(instance_variable_name)
      end

      client.instance_variable_get(instance_variable_name)
    end

    def dup_instance_variable_from_ancestor_chain(instance_variable_name)
      result = instance_variable_from_ancestor_chain(instance_variable_name).dup

      if block_given?
        result || yield
      else
        result
      end
    end
  end
end
