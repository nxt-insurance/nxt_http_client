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
      thread[RESPONSES]
    end

    def run_hydra_if_not_parallel
      return if parallel?

      hydra.run
    end

    def parallel?
      Thread.current[ID].present?
    end

    def set_response(request, response)
      responses[request] = response
      response
    end

    def get_response(request)
      responses[request]
    end

    def responses
      Thread.current[RESPONSES] ||= {}
    end

    def hydra(**opts)
      @hydra ||= Thread.current[ID] || build_hydra(**opts)
    end

    private

    def build_hydra(**opts)
      Typhoeus::Hydra.new(**opts)
    end

    def memoize_on_thread(**opts)
      Thread.current[ID] = build_hydra(**opts)
    end
  end
end
