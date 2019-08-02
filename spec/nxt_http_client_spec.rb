RSpec.describe NxtHttpClient do
  it 'has a version number' do
    expect(NxtHttpClient::VERSION).not_to be nil
  end

  context 'http methods', :vcr_cassette do
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
      end
    end

    subject do
      client.new
    end

    let(:url) { http_stats_url('200') }

    it 'calls fire with the respective http method' do
      expect(subject.post(url, params: { andy: 'calling' })).to eq('200 from level four class level')
      expect(subject.get(url)).to eq('200 from level four class level')
      expect(subject.patch(url)).to eq('200 from level four class level')
      expect(subject.put(url)).to eq('200 from level four class level')
      expect(subject.delete(url)).to eq('200 from level four class level')
    end
  end
end
