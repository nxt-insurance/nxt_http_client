module NxtHttpClient
  CONFIGURABLE_OPTIONS = %i[request_options base_url x_request_id_proc].freeze
  THREAD_CACHE_KEY = :nxt_http_client_cache_key

  Config = Struct.new('Config', *CONFIGURABLE_OPTIONS) do
    def initialize(request_options: ActiveSupport::HashWithIndifferentAccess.new, base_url: '', x_request_id_proc: nil)
      self.request_options = request_options
      self.base_url = base_url
      self.x_request_id_proc = x_request_id_proc
    end

    def dup
      self.class.new(**to_h.deep_dup)
    end
  end

  def build_thread_cache_key
    "#{SecureRandom.base58}::#{DateTime.current}"
  end

  def set_thread_cache_key
    Thread.current[THREAD_CACHE_KEY] ||= build_thread_cache_key
  end

  def clear_thread_cache_key
    Thread.current[THREAD_CACHE_KEY] = nil
  end

  module_function :set_thread_cache_key, :clear_thread_cache_key, :build_thread_cache_key
end
