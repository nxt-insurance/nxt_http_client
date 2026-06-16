module NxtHttpClient
  class Error < StandardError
    # Cert/trust failures — mapped to non-retryable CertificateError, kept out of the generic TlsError.
    CERTIFICATE_RETURN_CODES = %i[
      peer_failed_verification ssl_certproblem ssl_cacert_badfile ssl_issuer_error ssl_crl_badfile
    ].freeze

    REDACTED = '[REDACTED]'
    SENSITIVE_HEADERS = %w[Authorization Proxy-Authorization].freeze

    def self.from_response(response, message = nil)
      error_class_for(response).new(response, message)
    end

    def self.error_class_for(response)
      code = response.respond_to?(:code) ? response.code.to_i : 0
      return network_error_class(response.respond_to?(:return_code) ? response.return_code : nil) if code.zero?

      status_error_class(code)
    end

    def self.status_error_class(code)
      case code
      when 400 then BadRequest
      when 401 then Unauthorized
      when 403 then Forbidden
      when 404 then NotFound
      when 422 then UnprocessableEntity
      when 429 then TooManyRequests
      when 400..499 then ClientError
      when 500..599 then ServerError
      else self # 3xx etc. → base Error
      end
    end

    def self.network_error_class(return_code)
      case return_code
      when :operation_timedout then Timeout
      when :couldnt_connect then ConnectionFailed
      when :couldnt_resolve_host, :couldnt_resolve_proxy then NameResolutionError
      when *CERTIFICATE_RETURN_CODES then CertificateError
      else
        return_code.to_s.include?('ssl') ? TlsError : NetworkError
      end
    end

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
        request_options: redact_credentials(request_options),
        response_headers: response_headers,
        request_headers: redact_authorization(request_headers),
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
      return response.code if response.respond_to?(:code)
      
      0
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

    private

    # Keep Authorization tokens / basic-auth creds out of serialized output (to_h reaches Sentry).
    def redact_credentials(options)
      options = options.merge('userpwd' => REDACTED) if options.key?('userpwd')
      return options unless options['headers'].respond_to?(:key?)

      options.merge('headers' => redact_authorization(options['headers']))
    end

    def redact_authorization(headers)
      return headers unless headers.respond_to?(:keys)

      # HTTP header names are case-insensitive, and HashWithIndifferentAccess does not normalize case.
      sensitive = headers.keys.select { |key| SENSITIVE_HEADERS.any? { |name| key.to_s.casecmp?(name) } }
      return headers if sensitive.empty?

      headers.merge(sensitive.index_with { REDACTED })
    end

    public

    class ClientError < self; end
    class BadRequest < ClientError; end           # 400
    class Unauthorized < ClientError; end          # 401
    class Forbidden < ClientError; end             # 403
    class NotFound < ClientError; end              # 404
    class UnprocessableEntity < ClientError; end   # 422
    class TooManyRequests < ClientError; end       # 429

    class ServerError < self; end

    class NetworkError < self; end                # code 0 (no HTTP response)
    class Timeout < NetworkError; end             # :operation_timedout
    class ConnectionFailed < NetworkError; end    # :couldnt_connect
    class NameResolutionError < NetworkError; end # :couldnt_resolve_host / :couldnt_resolve_proxy
    class TlsError < NetworkError; end            # :ssl_connect_error and other non-cert :ssl_*

    # Sibling of NetworkError, not a child, so it's excluded from `retry_on NetworkError`.
    class CertificateError < self; end
  end
end
