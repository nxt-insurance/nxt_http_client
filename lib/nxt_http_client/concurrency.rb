module NxtHttpClient
  class Concurrency
    ID = 'NxtHttpClient::Hydra'
    RESPONSES = 'NxtHttpClient::Hydra::Responses'

    def parallel(**opts, &block)
      thread = Thread.new do
        hydra = memoize_on_thread(**opts)
        block.call
        hydra.run
      end

      thread.join
      responses(thread)
    end

    def sequential_or_parallel(&block)
      request = block.call(hydra)
      hydra.queue(request)
      return request if parallel?

      hydra.run
      get_response(request)
    end

    def set_response(request, response)
      responses[request] = response
      response
    end

    def get_response(request)
      responses[request]
    end

    def parallel?
      Thread.current[ID].present?
    end

    private

    def responses(thread = Thread.current)
      thread[RESPONSES] ||= {}
    end

    def hydra(**opts)
      @hydra ||= Thread.current[ID] || build_hydra(**opts)
    end

    def memoize_on_thread(**opts)
      Thread.current[ID] = build_hydra(**opts)
    end

    def build_hydra(**opts)
      Typhoeus::Hydra.new(**opts)
    end
  end
end
