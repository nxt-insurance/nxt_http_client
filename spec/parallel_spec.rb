RSpec.describe NxtHttpClient do
  describe '.parallel', :vcr_cassette do
    let(:client) do
      klass = Class.new(NxtHttpClient::Client) do
        configure do |config|
          config.base_url = nil
        end

        register_response_handler(NxtHttpClient::ResponseHandler.new) do |handler|
          handler.on(200) do |response|
            "handled #{response.request.options.fetch(:method)} request in parallel"
          end
        end
      end

      klass.new
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

      expect(result.values).to match_array(
        [
          "handled delete request in parallel",
          "handled get request in parallel",
          "handled patch request in parallel",
          "handled post request in parallel",
          "handled put request in parallel"
        ]
      )
    end
  end
end
