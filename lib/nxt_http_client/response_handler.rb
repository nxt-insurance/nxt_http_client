module NxtHttpClient
  class ResponseHandler
    CallbackAlreadyRegistered = Class.new(StandardError)
    include NxtRegistry

    def initialize
      @result = nil
    end

    attr_accessor :result

    def eval_callback(target, key, response)
      target.instance_exec(response, &callbacks.resolve(key))
    end

    def configure(&block)
      tap { |handler| block.call(handler) }
    end

    def register_callback(code, overwrite: false, &block)
      if overwrite
        callbacks.register!(code, block)
      else
        callbacks.register(code, block)
      end
    end

    def register_callback!(code, &block)
      register_callback(code, overwrite: true, &block)
    end

    alias on register_callback
    alias on! register_callback!

    def callback_for_response(response)
      key_from_response = response.code.to_s
      matching_any_callback = callbacks.resolve('any')
      return matching_any_callback if matching_any_callback.present?

      first_matching_key = callbacks.keys.sort.reverse.find do |key|
        regex_key = key.gsub('*', '[0-9]{1}')
        key_from_response =~ /\A#{regex_key}\z/
      end

      first_matching_key && callbacks.resolve(first_matching_key) ||
        response.success? && callbacks.resolve('success') ||
        response.timed_out? && callbacks.resolve('timed_out') ||
        !response.success? && callbacks.resolve('error') ||
        callbacks.resolve('others')
    end

    def callbacks
      @callbacks ||= NxtRegistry::Registry.new(
        :callbacks,
        call: false,
        on_key_already_registered: ->(key) { raise_callback_already_registered(key) }
      )
    end

    private

    def raise_callback_already_registered(code)
      msg = "Callback already registered for status: #{code}."
      msg << ' Use bang method to overwrite the callback.'
      raise CallbackAlreadyRegistered, msg
    end

    def initialize_copy(original)
      super
      @callbacks = original.send(:callbacks).clone
      @result = nil
    end
  end
end
