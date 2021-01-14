module NxtHttpClient
  class Concurrency
    ID = 'NxtHttpClient::Queue'
    RESPONSES = 'NxtHttpClient::Queue::Responses'
    RESULT_MAP = 'NxtHttpClient::Queue::ResultMap'

    def initialize
      @queue = []
    end

    def parallel(**opts, &block)
      results_need_to_be_mapped = block.arity == 1

      thread = Thread.new do
        memoize_queue_on_thread
        # TODO: Fix mapping
        results_need_to_be_mapped ? block.call(result_map) : block.call

        ::Parallel.map(queue, **opts) do |request|
          request.run
        end
      end

      thread.join

      if results_need_to_be_mapped
        map_results_by_requests(thread)
      else
        responses(thread)
      end
    end

    def sequential_or_parallel(&block)
      request = block.call(queue)
      queue << request
      return request if parallel?

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
      Thread.current[ID].present?
    end

    private

    attr_reader :queue

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

    def memoize_queue_on_thread
      Thread.current[ID] = queue
    end
  end
end
