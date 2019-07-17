module ClientDsl

  # TODO: Could also be something like:
  # register_defaults do |config|
  #   config.base_url = 'www.example.com'
  #   config.request_options = { ... }
  # end

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
    child.instance_variable_set(:@default_request_options, @default_request_options.dup)
    child.instance_variable_set(:@base_url, @base_url)
  end
end
