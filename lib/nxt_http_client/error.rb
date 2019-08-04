module NxtHttpClient
  class Error < StandardError
    def initialize(response)
      @response = response.blank? ? Typhoeus::Response.new : response
    end

    attr_reader :response

    def body
      if response_content_type == 'application/json'
        JSON.parse(response.body)
      else
        response.body
      end
    rescue ::JSON::JSONError
      response.body
    end

    def to_s
      "NxtHttpClient::Error::#{response_code}"
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


