RSpec.describe NxtHttpClient::Logging do
  let(:test_class) do
    Class.new(NxtHttpClient::Client) do
      def initialize
        @log = []
      end

      attr_accessor :log

      configure do |config|
        config.base_url = 'httpstat.us'
        config.request_options = {
          headers: { Accept: "text/html", Token: 'my custom token' }
        }
      end

      response_handler do |handler|
        handler.on(:success) do |response|
          "#{response}"
        end
      end

      self.logger = -> (info) { binding.pry; log("logged: #{info.to_h}") }

      def log(message)
        @log << message
      end
    end
  end

  let(:client) { test_class.new }

  before do
    client.get('200')
    client.get('201')
    client.get('202')
    client.get('203')
  end

  it 'logs', :vcr_cassette do
    binding.pry
  end
end
