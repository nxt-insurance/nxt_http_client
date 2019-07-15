module NxtHttpClient
  class CallbackKey < String
    def initialize(status)
      super(normalize_status(status))
    end

    private

    def normalize_status(status)
      return '***' if status == :any # overwrites all previous ones - comes at position 1

      return '2**' if status == :success # success?
      return '001' if status == :error # !success?
      return '000' if status == :others # this is a hack to move the others callback at last position

      status.to_s
    end
  end
end
