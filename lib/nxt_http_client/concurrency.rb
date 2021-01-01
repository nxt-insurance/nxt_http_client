module NxtHttpClient
  class Concurrency
    ID = 'NxtHttpClient::Hydra'
    RESPONSES = 'NxtHttpClient::Hydra::Responses'
    RESULT_MAP = 'NxtHttpClient::Hydra::ResultMap'

    def parallel(**opts, &block)
      results_need_to_be_mapped = block.arity == 1

      thread = Thread.new do
        hydra = memoize_on_thread(**opts)
        results_need_to_be_mapped ? block.call(result_map) : block.call
        hydra.run
      end

      thread.join

      if results_need_to_be_mapped
        map_results_by_requests(thread)
      else
        responses(thread)
      end
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

    def map_results_by_requests(thread)
      map = result_map(thread).invert

      responses(thread).inject({}) do |acc, (request, response)|
        key = map.fetch(request)
        acc[key] = response
        acc
      end
    end

    def result_map(thread = Thread.current)
      thread[RESULT_MAP] ||= {}
    end

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
