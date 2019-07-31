RSpec.describe NxtHttpClient do
  it 'has a version number' do
    expect(NxtHttpClient::VERSION).not_to be nil
  end

  describe '#post', :vcr_cassette do
    subject do
      NxtHttpClient::Client.new
    end

    let(:url) { http_stats_url('200') }

    it 'calls fire with the method set to :post' do
      result = subject.post(url)
      expect(result).to be_a(Typhoeus::Response)
      expect(result.body).to eq('200 OK')
    end
  end
end
