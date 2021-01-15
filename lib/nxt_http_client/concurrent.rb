module NxtHttpClient
  class Concurrent
    QUEUE = 'NxtHttpClient::Queue'
    RESULT_MAP = 'NxtHttpClient::Queue::ResultMap'

    def parallel(**opts, &block)
      results_need_to_be_mapped = block.arity == 1

      request_factory = Thread.new do
        init_queue
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

      results_need_to_be_mapped ? map_results(results, request_factory) : results
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

    private

    def map_results(results, thread)
      result_map(thread).inject({}) do |acc, (key, request)|
        acc[key] = results[request]
        acc
      end
    end

    def parallel?
      queue.is_a?(Array)
    end

    def queue(thread = Thread.current)
      thread[QUEUE]
    end

    def result_map(thread = Thread.current)
      thread[RESULT_MAP] ||= {}
    end

    def init_queue
      Thread.current[QUEUE] = []
    end
  end
end
