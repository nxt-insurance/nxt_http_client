module NxtHttpClient
  class Client
    extend ClientDsl
    CACHE_STRATEGIES = %w[global thread].freeze
    HTTP_METHODS = %w[get post patch put delete head].freeze

    def build_request(url, **opts)
      url = build_url(opts, url)
      opts = build_headers(opts)

      Typhoeus::Request.new(url, **opts.symbolize_keys)
    end

    delegate :before_fire_callback, :after_fire_callback, to: :class

    def fire(url = '', **opts, &block)
      concurrency.sequential_or_parallel do |_|
        request = build_request(url, **opts.except(:response_handler))

        response_handler = build_response_handler(opts[:response_handler], &block)
        run_before_fire_callback(request, response_handler)
        run_on_headers_callback(request, response_handler)
        run_on_body_callback(request, response_handler)

        result = nil
        current_error = nil

        request.on_complete do |response|
          result = callback_or_response(response, response_handler)
        rescue StandardError => error
          current_error = error
        ensure
          result = run_after_fire_callback(request, response, result, current_error)
          concurrency.set_response(request, result) || (raise current_error)
        end

        request
      end
    end

    HTTP_METHODS.each do |method|
      define_method method do |url = '', **opts, &block|
        fire(url, **opts.reverse_merge(method: method), &block)
      end
    end

    private

    def build_url(opts, url)
      base_url = opts.delete(:base_url) || default_config.base_url
      url = [base_url, url].reject(&:blank?).join('/')

      url_without_duplicated_hashes(url)
      url
    end

    def build_headers(opts)
      opts = default_config.request_options.with_indifferent_access.deep_merge(opts.with_indifferent_access)
      opts[:headers] ||= {}

      if default_config.x_request_id_proc
        opts[:headers][XRequestId] ||= default_config.x_request_id_proc.call
      end

      build_cache_header(opts)
      opts
    end

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

    def callback_or_response(response, response_handler)
      callback = response_handler.callback_for_response(response)
      callback && instance_exec(response, &callback) || response
    end

    def build_response_handler(handler, &block)
      response_handler = handler || dup_handler_from_class || NxtHttpClient::ResponseHandler.new
      response_handler.configure(&block) if block_given?
      response_handler
    end

    def run_before_fire_callback(request, response_handler)
      before_fire_callback && instance_exec(self, request, response_handler, &before_fire_callback)
    end

    def run_after_fire_callback(request, response, result, current_error)
      if after_fire_callback
        result = instance_exec(self, request, response, result, current_error, &after_fire_callback)
      end

      result
    end

    def run_on_headers_callback(request, response_handler)
      return unless response_handler.callbacks.resolve('headers')

      request.on_headers do |response|
        response_handler.eval_callback(self, 'headers', response)
      end
    end

    def run_on_body_callback(request, response_handler)
      return unless response_handler.callbacks.resolve('body')

      request.on_body do |response|
        response_handler.eval_callback(self, 'body', response)
      end
    end

    def concurrency
      @concurrency ||= Concurrency.new
    end
  end
end
