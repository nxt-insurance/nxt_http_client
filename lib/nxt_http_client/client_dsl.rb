module ClientDsl

  def register_defaults(defaults = OpenStruct.new, &block)
    @defaults = defaults
    @defaults.tap { |d| block.call(d) }
    @defaults
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

  def defaults
    @defaults
  end

  def base_url
    @base_url ||= (@defaults.base_url || '')
  end

  def default_request_options
    @default_request_options ||= (defaults.request_options || {})
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
    child.instance_variable_set(:@default_request_options, @default_request_options.deep_dup)
    child.instance_variable_set(:@base_url, @base_url)
    child.instance_variable_set(:@before_fire_callback, @before_fire_callback.dup)
    child.instance_variable_set(:@after_fire_callback, @after_fire_callback.dup)
    child.instance_variable_set(:@defaults, OpenStruct.new(**@defaults.to_h.deep_dup))
  end
end
