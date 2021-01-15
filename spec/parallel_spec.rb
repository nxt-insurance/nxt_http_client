RSpec.describe NxtHttpClient do
  describe '.parallel' do
    let(:client) do
      klass = Class.new(NxtHttpClient::Client) do
        configure do |config|
          config.base_url = nil
        end

        response_handler(NxtHttpClient::ResponseHandler.new) do |handler|
          handler.on(200) do |response|
            "handled #{response.request.options.fetch(:method)} request in parallel"
          end
        end
      end

      klass.new
    end

    let(:url) { http_stats_url('200') }

    context 'with results mapped' do
      it 'calls fire with the respective http method', :vcr_cassette do
        result = described_class.parallel(in_threads: 5) do |results|
          results[:post] = client.post(url, params: { andy: 'calling' })
          results[:get] = client.get(url)
          results[:patch] = client.patch(url)
          results[:put] = client.put(url)
          results[:delete] = client.delete(url)
        end

        expect(result).to eq(
          post: "handled post request in parallel",
          get: "handled get request in parallel",
          patch: "handled patch request in parallel",
          put: "handled put request in parallel",
          delete: "handled delete request in parallel"
        )
      end
    end

    context 'without mapping results' do
      it 'calls fire with the respective http method', :vcr_cassette do
        result = described_class.parallel(in_processes: 5) do
          client.post(url, params: { andy: 'calling' })
          client.get(url)
          client.patch(url)
          client.put(url)
          client.delete(url)
        end

        # when we do not map results keys are the requests
        #cexpect(result.keys).to all(be_a(Typhoeus::Request))

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
end
