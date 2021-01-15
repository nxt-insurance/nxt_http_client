module NxtHttpClient
  class Client
    extend ClientDsl

    HTTP_METHODS = %w[get post patch put delete head].freeze

    def fire(url = '', **opts, &block)
      concurrent.sequential_or_parallel do
        RequestExecutor.new(self, url, **opts, &block)
      end
    end

    HTTP_METHODS.each do |method|
      define_method method do |url = '', **opts, &block|
        fire(url, **opts.reverse_merge(method: method), &block)
      end
    end

    private

    def concurrent
      @concurrent ||= NxtHttpClient::Concurrent.new
    end
  end
end
