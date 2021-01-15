module NxtHttpClient
  class RequestBuilder
    CACHE_STRATEGIES = %w[global thread].freeze

    def initialize(client, url, **opts)
      @client = client
      @url = build_url(opts, url)
      @opts = build_headers(opts)
    end

    def call
      Typhoeus::Request.new(url, **opts.symbolize_keys)
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

    def config
      client.class.config
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

    attr_reader :client, :url, :opts
  end
end
