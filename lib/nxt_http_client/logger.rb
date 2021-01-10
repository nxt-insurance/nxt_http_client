module NxtHttpClient
  class Logger
    def initialize(logger)
      @logger = logger
    end

    def call(client, request, _response_handler, fire)
      started_at = now
      error = nil
      result = nil

      options = {
        client: client,
        started_at: started_at,
        request: request
      }

      begin
        result = fire.call
      rescue => e
        error = e
        options.merge!(error: e)
      ensure
        finished_at = now
        options.merge!(
          finished_at: now,
          elapsed_time_in_milliseconds: finished_at - started_at,
          response: request.response,
          http_status: request.response&.code
        )
      end

      logger.call(options)
      raise error if error

      result
    end

    private

    attr_reader :logger

    def now
      Time.current.to_i * 1000
    end
  end
end
