module NxtHttpClient
  class Client
    extend ClientDsl

    def build_request(url, **opts)
      base_url = opts.delete(:base_url) || self.class.base_url
      url = [base_url, url].reject(&:blank?).join('/')
      opts = self.class.default_request_options.deep_merge(opts)

      Typhoeus::Request.new(url, opts)
    end

    def fire(url = '', **opts, &block)
      # calling_method = caller_locations(1,1)[0].label
      response_handler = opts.fetch(:response_handler) { dup_handler_from_class }
      response_handler.configure(&block) if block_given?
      request = build_request(url, opts.except(:response_handler))

      before_fire_callback = self.class.before_fire_callback
      before_fire_callback && instance_exec(request, &before_fire_callback)

      if response_handler.callbacks['headers']
        request.on_headers do |response|
          response_handler.eval_callback(self, 'headers', response)
        end
      end

      if response_handler.callbacks['body']
        request.on_body do |response|
          response_handler.eval_callback(self, 'body', response)
        end
      end

      result = nil

      request.on_complete do |response|
        callback = response_handler.callback_for_response(response)
        result = callback && instance_exec(response, &callback) || response

        after_fire_callback = self.class.after_fire_callback
        after_fire_callback && instance_exec(request, result, response, &after_fire_callback)

        result
      end

      request.run

      result
    end

    def dup_handler_from_class
      self.class.response_handler.dup
    end
  end
end
