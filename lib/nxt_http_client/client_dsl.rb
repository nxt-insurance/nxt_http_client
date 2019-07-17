module ClientDsl
  def base_url=(base_url)
    @base_url = base_url
  end

  def base_url
    @base_url ||= ''
  end

  def default_request_options=(opts)
    @default_request_options = opts
  end

  def default_request_options
    @default_request_options ||= {}
  end

  # TODO: Make the class level interface uniform. Either with attr_accessor or using blocks
  def response_handler(handler = nil, &block)
    @response_handler = handler if handler

    if block_given?
      @response_handler ||= dup_handler_from_ancestor_or_new
      @response_handler.configure(&block)
    else
      @response_handler
    end
  end

  def dup_handler_from_ancestor_or_new
    handler_from_ancestor = ancestors[1].instance_variable_get(:@response_handler)
    handler_from_ancestor && handler_from_ancestor.dup || NxtHttpClient::ResponseHandler.new
  end

  def inherited(child)
    child.instance_variable_set(:@response_handler, @response_handler.dup)
    child.instance_variable_set(:@default_request_options, @default_request_options.dup)
    child.instance_variable_set(:@base_url, @base_url)
  end
end
