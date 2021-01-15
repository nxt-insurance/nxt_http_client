module NxtHttpClient
  class Concurrency
    ID = 'NxtHttpClient::Queue'
    RESPONSES = 'NxtHttpClient::Queue::Responses'
    RESULT_MAP = 'NxtHttpClient::Queue::ResultMap'

    def parallel(**opts, &block)
      results_need_to_be_mapped = block.arity == 1

      thread = Thread.new do
        init_parallelization
        # TODO: Fix mapping
        results_need_to_be_mapped ? block.call(result_map) : block.call
      end

      thread.join

      results = ::Parallel.map(thread[ID], **opts) do |request|
        { request => request.run }
      end

      results = results.inject({}) do |acc, hash|
        acc.merge(hash)
      end

      if results_need_to_be_mapped
        binding.pry
        map_results_by_requests(thread)
      else
        results
      end
    end

    def sequential_or_parallel(&block)
      request = block.call

      if parallel?
        queue << request
        return request
      end

      request.run
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
      Thread.current[ID].is_a?(Array)
    end

    private

    def queue
      Thread.current[ID]
    end

    def map_results_by_requests(thread)
      result_map(thread).inject({}) do |acc, (key, request)|
        acc[key] = request.response.handled_response
        acc
      end
    end

    def result_map(thread = Thread.current)
      thread[RESULT_MAP] ||= {}
    end

    def responses(thread = Thread.current)
      thread[RESPONSES] ||= {}
    end

    def init_parallelization
      Thread.current[ID] = []
    end
  end
end
