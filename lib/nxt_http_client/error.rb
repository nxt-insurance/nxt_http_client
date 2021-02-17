module NxtHttpClient
  class Error < StandardError
    def initialize(response, message = nil)
      @response = response.blank? ? Typhoeus::Response.new : response
      @id = SecureRandom.uuid
      @message = message || default_message

      super(@message)
    end

    attr_reader :response, :id, :message
    delegate :timed_out?, :status_message, to: :response

    alias_method :to_s, :message

    def default_message
      "#{self.class.name}::#{response_code}"
    end

    def to_h
      {
        id: id,
        url: url,
        response_code: response_code,
        request_options: request_options,
        response_headers: response_headers,
        request_headers: request_headers,
        body: body,
        x_request_id: x_request_id
      }
    end

    def body
      if response_content_type&.starts_with?(ApplicationJson)
        JSON.parse(response.body)
      else
        response.body
      end
    rescue ::JSON::JSONError
      response.body
    end

    def response_code
      response.code || 0
    end

    def request
      @request ||= response.request || Typhoeus::Request.new('/dev/null', {})
    end

    def url
      request.url
    end

    def x_request_id
      request_headers[XRequestId]
    end

    def request_options
      @request_options ||= (request.original_options || {}).with_indifferent_access
    end

    def request_headers
      @request_headers ||= (request.original_options[:headers] || {}).with_indifferent_access
    end

    def response_options
      @response_options ||= (response.options || {}).with_indifferent_access
    end

    def response_headers
      @response_headers ||= (response.headers || {}).with_indifferent_access
    end

    def response_content_type
      response_headers['Content-Type']
    end
  end
end
