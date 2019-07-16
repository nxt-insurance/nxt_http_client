module NxtHttpClient
  class Client
    # Probably want to move out the DSL
    extend ClientDsl

    def build_request(url, **opts)
      base_url = opts.delete(:base_url) || self.class.base_url
      url = [base_url, url].join('/')
      opts = self.class.default_options.deep_merge(opts)

      Typhoeus::Request.new(url, opts)
    end

    def fire(request, response_handler: dup_handler_from_class, &block)
      response_handler.configure(&block) if block_given?

      if response_handler.callbacks['headers']
        request.on_headers do |response|
          response_handler.callbacks['headers'].call(response)
        end
      end

      if response_handler.callbacks['body']
        request.on_body do |response|
          response_handler.callbacks['body'].call(response)
        end
      end

      request.on_complete do |response|
        response_handler.call(response)
      end

      request.run

      response_handler.result
    end

    def dup_handler_from_class
      self.class.response_handler.dup
    end
  end
end
