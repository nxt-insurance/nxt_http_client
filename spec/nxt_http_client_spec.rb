RSpec.describe NxtHttpClient do
  it 'has a version number' do
    expect(NxtHttpClient::VERSION).not_to be nil
  end

  describe '.make', :vcr_cassette do
    let(:client) do
      NxtHttpClient::Client.make do
        configure do |config|
          config.base_url = 'httpstat.us'
        end

        response_handler(NxtHttpClient::ResponseHandler.new) do |handler|
          handler.on(200) do |response|
            response.body
          end
        end
      end
    end

    it 'returns an anonymous client' do
      expect(client).to be_a(NxtHttpClient::Client)
      expect(client.get('200')).to eq('200 OK')
    end
  end

  context 'http methods', :vcr_cassette do
    let(:client) do
      Class.new(NxtHttpClient::Client) do
        configure do |config|
          config.base_url = nil
        end

        response_handler(NxtHttpClient::ResponseHandler.new) do |handler|
          handler.on(200) do |response|
            '200 from level four class level'
          end
        end
      end
    end

    subject do
      client.new
    end

    let(:url) { http_status_url('200') }

    it 'calls fire with the respective http method' do
      expect(subject.post(url, params: { andy: 'calling' })).to eq('200 from level four class level')
      expect(subject.get(url)).to eq('200 from level four class level')
      expect(subject.patch(url)).to eq('200 from level four class level')
      expect(subject.put(url)).to eq('200 from level four class level')
      expect(subject.delete(url)).to eq('200 from level four class level')
    end
  end
end
