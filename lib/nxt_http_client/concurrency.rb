module NxtHttpClient
  class Concurrency
    ID = 'NxtHttpClient::Queue'
    RESPONSES = 'NxtHttpClient::Queue::Responses'
    RESULT_MAP = 'NxtHttpClient::Queue::ResultMap'

    def parallel(**opts, &block)
      results_need_to_be_mapped = block.arity == 1

      request_factory = Thread.new do
        init_parallelization
        results_need_to_be_mapped ? block.call(result_map) : block.call
      end

      request_factory.join

      results = ::Parallel.map(queue(request_factory), **opts) do |request|
        { request => request.run }
      end

      results = results.inject({}) do |acc, request_response_hash|
        acc[request_response_hash.keys.first] = request_response_hash.values.first&.handled_response
        acc
      end

      if results_need_to_be_mapped
        result_map(request_factory).inject({}) do |acc, (key, request)|
          acc[key] = results[request]
          acc
        end
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

      result = request.run
      result&.handled_response
    end

    def parallel?
      Thread.current[ID].is_a?(Array)
    end

    private

    def queue(thread = Thread.current)
      thread[ID]
    end

    def result_map(thread = Thread.current)
      thread[RESULT_MAP] ||= {}
    end

    def init_parallelization
      Thread.current[ID] = []
    end
  end
end
