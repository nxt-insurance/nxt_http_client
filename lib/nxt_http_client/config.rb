module NxtHttpClient
  CONFIGURABLE_OPTIONS = {
    request_options: ActiveSupport::HashWithIndifferentAccess.new,
    base_url: '',
    x_request_id_proc: nil,

    # Helper to set the Content-Type request header and automatically convert request bodies to JSON
    json_request: false,
    # Helper to set the Accept request header and automatically convert success response bodies to JSON
    json_response: false,
    raise_response_errors: false,

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

    def timeout_seconds(total:, connect: nil)
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
