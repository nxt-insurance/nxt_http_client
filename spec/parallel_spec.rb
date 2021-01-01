RSpec.describe NxtHttpClient do
  describe '.parallel', :vcr_cassette do
    let(:client) do
      Class.new(NxtHttpClient::Client) do
        configure do |config|
          config.base_url = nil
        end

        register_response_handler(NxtHttpClient::ResponseHandler.new) do |handler|
          handler.on(200) do |response|
            '200 from level four class level'
          end
        end
      end.new
    end

    let(:url) { http_stats_url('200') }

    it 'calls fire with the respective http method' do
      result = described_class.parallel do
        client.post(url, params: { andy: 'calling' })
        client.get(url)
        client.patch(url)
        client.put(url)
        client.delete(url)
      end

      expect(result.values).to match_array(['200 from level four class level'] * 5)
    end
  end
end
