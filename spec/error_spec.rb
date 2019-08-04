RSpec.describe NxtHttpClient::Error do
  context 'when the request is blank somehow' do
    subject do
      described_class.new(nil)
    end

    it 'responds to all methods' do
      expect(subject.body).to be_nil
      expect(subject.url).to eq("/dev/null")
      expect(subject.request).to be_a(Typhoeus::Request)
      expect(subject.request_options).to eq({})
      expect(subject.request_headers).to eq({})
      expect(subject.response_options).to eq({})
      expect(subject.response_headers).to eq({})
      expect(subject.response_content_type).to be_nil
    end
  end
end
