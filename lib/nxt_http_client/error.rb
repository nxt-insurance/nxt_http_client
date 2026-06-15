module NxtHttpClient
  # Included in the network-error subclasses that are safe to retry (timeout, connection refused, DNS).
  # Consumers can `retry_on NxtHttpClient::TransientError` without per-client wiring. Deliberately NOT
  # included in CertificateError — a failed cert/CA verification is permanent, retrying never helps.
  module TransientError; end

  class Error < StandardError
    # libcurl return_code (Typhoeus::Response#return_code) → mapped subclass. Cert/trust failures are
    # split out from generic TLS errors so they can stay non-transient.
    CERTIFICATE_RETURN_CODES = %i[
      peer_failed_verification ssl_certproblem ssl_cacert_badfile ssl_issuer_error ssl_crl_badfile
    ].freeze

    # Build the right error for a response: code-0 (no HTTP response) maps to a network subclass by
    # return_code; anything else stays the base Error (preserves prior behavior for 4xx/5xx).
    def self.from_response(response, message = nil)
      error_class_for(response).new(response, message)
    end

    def self.error_class_for(response)
      return self unless response_code_zero?(response)

      network_error_class(response.respond_to?(:return_code) ? response.return_code : nil)
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

    def self.response_code_zero?(response)
      (response.respond_to?(:code) ? response.code : 0).to_i.zero?
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

    # Base for all code-0 (no HTTP response received) failures. Transient by default — see TransientError.
    class NetworkError < self
      include TransientError
    end

    class Timeout < NetworkError; end             # :operation_timedout
    class ConnectionFailed < NetworkError; end    # :couldnt_connect
    class NameResolutionError < NetworkError; end # :couldnt_resolve_host / :couldnt_resolve_proxy
    class TlsError < NetworkError; end            # :ssl_connect_error and other non-cert :ssl_*

    # Cert/CA verification failures — permanent, so NOT a NetworkError (would inherit the transient marker).
    class CertificateError < Error; end
  end
end
