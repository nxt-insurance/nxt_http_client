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

    def fire(url = '', **opts, &block)
      # concurrency.sequential_or_parallel do
      #   request = build_request(url, **opts.except(:response_handler))
      #
      #   response_handler = build_response_handler(opts[:response_handler], &block)
      #   run_before_fire_callback(request, response_handler)
      #   run_on_headers_callback(request, response_handler)
      #   run_on_body_callback(request, response_handler)
      #
      #   result = nil
      #   current_error = nil
      #
      #   request.on_complete do |response|
      #     result = callback_or_response(response, response_handler)
      #   rescue StandardError => error
      #     current_error = error
      #   ensure
      #     result = run_after_fire_callback(request, response, result, current_error)
      #     result || (raise current_error)
      #   end
      #
      #   request
      # end
      concurrent.sequential_or_parallel do
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
    end

    HTTP_METHODS.each do |method|
      define_method method do |url = '', **opts, &block|
        fire(url, **opts.reverse_merge(method: method), &block)
      end
    end

    private

    def build_url(opts, url)
      base_url = opts.delete(:base_url) || config.base_url
      url = [base_url, url].reject(&:blank?).join('/')

      url_without_duplicated_hashes(url)
      url
    end

    def build_headers(opts)
      opts = config.request_options.with_indifferent_access.deep_merge(opts.with_indifferent_access)
      opts[:headers] ||= {}

      if config.x_request_id_proc
        opts[:headers][XRequestId] ||= config.x_request_id_proc.call
      end

      build_cache_header(opts)
      opts
    end

    def dup_handler_from_class
      self.class.response_handler.dup
    end

    def config
      self.class.config
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

    def run_before_fire_callbacks(request, response_handler)
      callbacks.run_before(target: self, request: request, response_handler: response_handler)
    end

    def run_around_fire_callbacks(request, response_handler, &fire)
      callbacks.run_around(
        target: self,
        request: request,
        response_handler: response_handler,
        fire: fire
      )
    end

    def run_after_fire_callbacks(request, response, result, current_error)
      return result unless callbacks.any_after_callbacks?

      callbacks.run_after(
        target: self,
        request: request,
        response: response,
        result: result,
        error: current_error
      )
    end

    def setup_on_headers_callback(request, response_handler)
      return unless response_handler.callbacks.resolve('headers')

      request.on_headers do |response|
        response_handler.eval_callback(self, 'headers', response)
      end
    end

    def setup_on_body_callback(request, response_handler)
      return unless response_handler.callbacks.resolve('body')

      request.on_body do |response|
        response_handler.eval_callback(self, 'body', response)
      end
    end

    def callbacks
      @callbacks ||= self.class.callbacks
    end

    def concurrent
      @concurrent ||= NxtHttpClient::Concurrent.new
    end
  end
end
