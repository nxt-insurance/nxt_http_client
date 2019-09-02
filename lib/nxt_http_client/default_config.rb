module NxtHttpClient
  CONFIGURABLE_OPTIONS = %i[request_options base_url x_request_id_proc]

  DefaultConfig = Struct.new('DefaultConfig', *CONFIGURABLE_OPTIONS) do
    def initialize(request_options: ActiveSupport::HashWithIndifferentAccess.new, base_url: '', x_request_id_proc: nil)
      self.request_options = request_options
      self.base_url = base_url
      self.x_request_id_proc = x_request_id_proc
    end

    def dup
      self.class.new(**to_h.deep_dup)
    end
  end
end
