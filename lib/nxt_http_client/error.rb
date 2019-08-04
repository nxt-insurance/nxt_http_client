module NxtHttpClient
  class Error < StandardError
    def initialize(response = Typhoeus::Response.new)
      @response = response
    end

    attr_reader :response

    def body
      if response_content_type.include?('application')
        JSON.parse(response.body)
      else
        response.body
      end
    rescue JSONError
      response.body
    end

    def request
      @request ||= response.request || Typhoeus::Request.new('/dev/null', {})
    end

    def url
      response.url
    end

    def request_options
      @request_options ||= (request.original_options || {}).with_indifferent_access
    end

    def request_headers
      @request_headers ||= (response.request.original_options[:headers] || {}).with_indifferent_access
    end

    def response_options
      @response_options ||= (response.options || {}).with_indifferent_access
    end

    def response_headers
      @response_headers ||= (response_options[:headers] || {}).with_indifferent_access
    end

    def response_content_type
      response_headers['Content-Type']
    end
  end
end


