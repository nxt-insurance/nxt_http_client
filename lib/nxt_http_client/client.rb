module NxtHttpClient
  class Client
    extend ClientDsl
    CACHE_STRATEGIES = %w[global thread]

    def build_request(url, **opts)
      base_url = opts.delete(:base_url) || default_config.base_url
      url = [base_url, url].reject(&:blank?).join('/')

      url_without_duplicated_hashes(url)

      opts = default_config.request_options.with_indifferent_access.deep_merge(opts.with_indifferent_access)
      opts[:headers] ||= {}

      if default_config.x_request_id_proc
        opts[:headers]['X-Request-ID'] ||= default_config.x_request_id_proc.call
      end

      build_cache_header(opts)

      Typhoeus::Request.new(url, **opts.symbolize_keys)
    end

    def fire(url = '', **opts, &block)
      # calling_method = caller_locations(1,1)[0].label
      response_handler = opts.fetch(:response_handler) do
        dup_handler_from_class || NxtHttpClient::ResponseHandler.new
      end

      response_handler.configure(&block) if block_given?
      request = build_request(url, opts.except(:response_handler))

      before_fire_callback = self.class.before_fire_callback
      before_fire_callback && instance_exec(self, request, response_handler, &before_fire_callback)

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
      error = nil

      request.on_complete do |response|
        callback = response_handler.callback_for_response(response)
        result = callback && instance_exec(response, &callback) || response
      rescue StandardError => e
        error = e
      ensure
        after_fire_callback = self.class.after_fire_callback

        if after_fire_callback
          result = instance_exec(self, request, response, result, error, &after_fire_callback)
        else
          result || (raise error)
        end
      end

      request.run

      result
    end

    %w[get post patch put delete head].each do |method|
      define_method method do |url = '', **opts, &block|
        fire(url, opts.reverse_merge(method: method), &block)
      end
    end

    private

    def dup_handler_from_class
      self.class.response_handler.dup
    end

    def default_config
      self.class.default_config
    end

    def build_cache_header(opts)
      if opts[:cache] ||= false
        strategy = opts.delete(:cache)

        case strategy.to_s
        when 'thread'
          cache_key = Thread.current[:nxt_http_client_cache_key] ||= "#{SecureRandom.base58}::#{DateTime.current}"
          opts[:headers].reverse_merge!(cache_key: cache_key)
        when 'global'
          opts[:headers].delete(:cache_key)
        else
          raise ArgumentError, "Cache strategy unknown: #{strategy}. Options are #{CACHE_STRATEGIES}"
        end
      end
    end

    def url_without_duplicated_hashes(url)
      duplicated_slashes = url.match(/([^:]\/{2,})/)
      duplicated_slashes && duplicated_slashes.captures.each do |capture|
        url.gsub!(capture, "#{capture[0]}/")
      end

      url
    end

  end
end
