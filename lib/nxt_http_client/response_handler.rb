module NxtHttpClient
  class ResponseHandler
    CallbackAlreadyRegistered = Class.new(StandardError)

    def initialize
      @callbacks = {}
      @result = nil
    end

    attr_accessor :result
    attr_reader :callbacks

    # def call(response)
    #   callback = callback_for_response(response)
    #
    #   if callback
    #     self.result = callback.call(response)
    #   else
    #     self.result = response
    #   end
    # end

    def configure(&block)
      tap { |handler| block.call(handler) }
    end

    def register_callback(code, overwrite: false, &block)
      key = code.to_s
      # This would add callbacks to the response handler
      unless overwrite
        callbacks[key].present? && raise_callback_already_registered(code)
      end

      callbacks[key] = block
    end

    def register_callback!(code, &block)
      register_callback(code, overwrite: true, &block)
    end

    alias_method :on, :register_callback
    alias_method :on!, :register_callback!

    def callback_for_response(response)
      key_from_response = response.code.to_s

      first_matching_key = callbacks.keys.sort.reverse.find do |key|
        regex_key = key.gsub('*', '[0-9]{1}')
        key_from_response =~ /\A#{regex_key}\z/
      end

      first_matching_key && callbacks[first_matching_key] ||
      response.success? && callbacks['success'] ||
      response.timed_out? && callbacks['timed_out'] ||
      !response.success? && callbacks['error'] ||
      callbacks['others']
    end

    private

    def raise_callback_already_registered(code)
      msg = "Callback already registered for status: #{code}."
      msg << ' Use bang method to overwrite the callback.'
      raise CallbackAlreadyRegistered, msg
    end

    # we need to dup callbacks since dup is shallow
    def initialize_copy(original)
      super
      @callbacks = original.send(:callbacks).dup
      @result = nil
    end
  end
end
