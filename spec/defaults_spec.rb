RSpec.describe NxtHttpClient::Client do

  let(:level_one) do
    Class.new(described_class) do
      register_defaults do |defaults|
        defaults.base_url = 'httpstat.us'
        defaults.request_options = { method: :get }
      end

      register_response_handler do |handler|
        handler.on(200) do |response|
          response.request.original_options.symbolize_keys
        end

        handler.on('400') do |response|
          response.request.base_url
        end
      end

      def call(status)
        fire(status)
      end
    end
  end

  subject do
    level_one.new
  end

  describe '.default_request_options' do
    it 'builds the request with the default options', :vcr_cassette do
      expect(subject.call('200')).to eq(method: :get, cache: false, headers: {})
    end
  end

  describe '.base_url' do
    it 'builds the request with the base url', :vcr_cassette do
      expect(subject.call('400')).to eq("httpstat.us/400")
    end
  end
end
