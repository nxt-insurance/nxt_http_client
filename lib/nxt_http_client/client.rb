module NxtHttpClient
  # The entry point to this gem. The Client class is designed to be extended into custom base classes,
  # but you can also create a one-off instance with the `.make` method.`
  class Client
    extend ClientDsl

    CACHE_STRATEGIES = %w[global thread].freeze
    HTTP_METHODS = %w[get post patch put delete head].freeze

    # Get an anonymous client for one-off use. Example:
    #
    #   client = NxtHttpClient::Client.make do
    #     configure do |config|
    #       config.base_url = 'www.httpstat.us'
    #     end
    #   end
    #   client.get('200')
    def self.make(&block)
      Class.new(self, &block).new
    end

    def build_request(url, **opts)
      url = build_url(opts, url)
      opts = build_headers(opts)

      set_timeouts(opts)

      if config.json_request
        opts[:body] = opts[:body].to_json # Typhoeus requires userland JSON encoding
      end

      Typhoeus::Request.new(url, **opts.symbolize_keys)
    end

    def fire(url = '', **opts, &block)
      response_handler = build_response_handler(opts[:response_handler], &block)
      request = build_request(url, **opts.except(:response_handler))

      current_error = nil
      result = nil

      setup_on_headers_callback(request, response_handler)
      setup_on_body_callback(request, response_handler)

      request.on_complete do |response|
        result = callback_or_response(response, response_handler)
      end

      run_before_fire_callbacks(request, response_handler)

      run_around_fire_callbacks(request, response_handler) do
        request.run
      rescue StandardError => error
        current_error = error
      end

      result = run_after_fire_callbacks(request, request.response, result, current_error)
      result || (raise current_error if current_error)

      result
    end

    HTTP_METHODS.each do |method|
      define_method method do |url = '', **opts, &block|
        fire(url, **opts.reverse_merge(method:), &block)
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

      opts[:headers]['Content-Type'] ||= ApplicationJson if config.json_request
      opts[:headers]['Accept'] ||= ApplicationJson if config.json_response

      if config.basic_auth
        begin
          config.basic_auth => { username:, password: }
        rescue NoMatchingPatternKeyError
          raise ArgumentError, 'basic_auth must be a Hash with :username and :password'
        end
        opts[:userpwd] ||= "#{username}:#{password}"
      elsif (bearer_token = config.bearer_auth)
        opts[:headers]['Authorization'] ||= "Bearer #{bearer_token}"
      end

      opts[:headers][XRequestId] ||= config.x_request_id_proc.call if config.x_request_id_proc

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

    def set_timeouts(opts)
      if (timeouts = config.timeouts).is_a?(Hash)
        opts[:timeout] ||= timeouts[:total]
        opts[:connecttimeout] ||= timeouts[:connect]
      end

      raise ArgumentError, 'You must configure a total timeout for this client or request' unless timeout_configured?(opts)
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

      if config.json_response
        response_handler.configure do |handler|
          handler.on(:success) do |response|
            response.define_singleton_method(:body) { JSON(response.response_body) }
            response
          end
        end
      end

      if config.raise_response_errors
        response_handler.configure do |handler|
          handler.on(:error) do |response|
            error = NxtHttpClient::Error.new(response)
            ::Sentry.set_extras(http_error_details: error.to_h) if defined?(::Sentry)
            raise error
          end
        end
      end

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

    def timeout_configured?(opts)
      [:timeout, :timeout_ms].any? { opts[_1].present? }
    end
  end
end
