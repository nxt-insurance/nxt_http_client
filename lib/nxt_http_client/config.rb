module NxtHttpClient
  CONFIGURABLE_OPTIONS = %i[request_options base_url x_request_id_proc].freeze

  Config = Struct.new('Config', *CONFIGURABLE_OPTIONS) do
    def initialize(request_options: ActiveSupport::HashWithIndifferentAccess.new, base_url: '', x_request_id_proc: nil)
      self.request_options = request_options
      self.base_url = base_url
      self.x_request_id_proc = x_request_id_proc
    end

    # Helper to add the request headers for JSON.
    # You still need to use JSON(response.body) or the JSON response_handler to get a JSON response.
    def request_json
      self.request_options.deep_merge!(
        headers: { 'Content-Type': 'application/json', "Accept": 'application/json' }
      )

      @send_json = true
    end

    def basic_auth(username, password)
      self.request_options.merge!(
        userpwd: "#{username}:#{password}"
      )
    end

    def bearer_auth(token)
      self.request_options.deep_merge!(
        headers: { 'Authorization': "Bearer #{token}" }
      )
    end

    def timeout_seconds(total: nil, connect: nil)
      timeouts = {
        timeout: total,
        connecttimeout: connect
      }.compact

      self.request_options.merge!(**timeouts)
    end

    def dup
      self.class.new(**to_h.deep_dup)
    end

    def send_json? = @send_json
  end
end
