module NxtHttpClient
  CONFIGURABLE_OPTIONS = {
    request_options: ActiveSupport::HashWithIndifferentAccess.new,
    base_url: '',
    x_request_id_proc: nil,
    # Helper to add the request headers for JSON.
    # You still need to use JSON(response.body) or the JSON response_handler to get a JSON response.
    # TODO: implement a JSON response handler that parses responses and raises errors
    json_headers: false,
    bearer_auth: nil,
    basic_auth: nil,
    timeouts: nil,
  }.freeze

  Config = Struct.new('Config', *CONFIGURABLE_OPTIONS.keys) do
    def initialize
      CONFIGURABLE_OPTIONS.each do |key, default_value|
        self.send(:"#{key}=", default_value.dup)
      end
    end

    def timeout_seconds(total: nil, connect: nil)
      timeouts = { total:, connect:, }.compact

      self.timeouts = timeouts
    end

    def dup
      options = to_h
      self.class.new.tap do |instance|
        options.each do |key, value|
          instance.send(:"#{key}=", value.dup)
        end
      end
    end
  end
end
