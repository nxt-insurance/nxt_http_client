module NxtHttpClient
  class RequestExecutor
    def initialize(client, url, **opts, &block)
      @client = client
      @url = url
      @opts = opts
      @block = block
    end

    def call
      response_handler = build_response_handler(opts[:response_handler], &block)
      request = build_request(url, **opts.except(:response_handler))

      current_error = nil
      result = nil

      setup_on_headers_callback(request, response_handler)
      setup_on_body_callback(request, response_handler)

      run_before_fire_callbacks(request, response_handler)

      request.on_complete do |response|
        result = callback_or_response(response, response_handler)
      end

      run_around_fire_callbacks(request, response_handler) do
        request.run
      rescue StandardError => error
        current_error = error
      end

      result = run_after_fire_callbacks(request, request.response, result, current_error)
      result || (raise current_error if current_error)

      result
    end

    private

    attr_reader :client, :url, :opts, :block

    def build_request(url, **opts)
      RequestBuilder.new(client, url, **opts).call
    end

    def build_response_handler(handler, &block)
      response_handler = handler || dup_handler_from_client_class || NxtHttpClient::ResponseHandler.new
      response_handler.configure(&block) if block_given?
      response_handler
    end

    def dup_handler_from_client_class
      client.class.response_handler.dup
    end

    def callback_or_response(response, response_handler)
      callback = response_handler.callback_for_response(response)
      callback && client.instance_exec(response, &callback) || response
    end

    def run_before_fire_callbacks(request, response_handler)
      callbacks.run_before(target: client, request: request, response_handler: response_handler)
    end

    def run_around_fire_callbacks(request, response_handler, &fire)
      callbacks.run_around(
        target: client,
        request: request,
        response_handler: response_handler,
        fire: fire
      )
    end

    def run_after_fire_callbacks(request, response, result, current_error)
      return result unless callbacks.any_after_callbacks?

      callbacks.run_after(
        target: client,
        request: request,
        response: response,
        result: result,
        error: current_error
      )
    end

    def setup_on_headers_callback(request, response_handler)
      return unless response_handler.callbacks.resolve('headers')

      request.on_headers do |response|
        response_handler.eval_callback(client, 'headers', response)
      end
    end

    def setup_on_body_callback(request, response_handler)
      return unless response_handler.callbacks.resolve('body')

      request.on_body do |response|
        response_handler.eval_callback(client, 'body', response)
      end
    end

    def callbacks
      @callbacks ||= client.class.callbacks
    end
  end
end
