module NxtHttpClient
  class Logging
    def initialize(logger)
      @logger = logger
    end

    def to_proc
      method(:call)
    end

    def call(client, request, _response_handler, fire)
      options = {
        client: client,
        started_at: now,
        request: request,
        response: request.response
      }

      error = nil
      result = nil

      begin
        result = fire.call
      rescue => e
        error = e
        options.merge!(error: e)
      ensure
        options.merge!(
          finished_at: now,
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
