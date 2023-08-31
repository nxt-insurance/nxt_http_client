RSpec.describe 'upload' do
  let(:destination) { 'https://ptsv2.com/t/nxt_http_client/post' }

  let(:client) do
    Class.new(NxtHttpClient::Client) do
      configure do |config|
        config.timeout_seconds(total: 60)
      end

      response_handler do |handler|
        handler.on(200) { |response| response }
      end
    end
  end

  let(:file_path) { File.expand_path('support/test_file.txt', File.dirname(__FILE__)) }
  let(:file_1) { File.open(file_path, "r") }
  let(:file_2) { File.open(file_path, "r") }

  subject do
    client.new
  end

  it 'uploads the files', :vcr_cassette do
    result = subject.post(
      destination,
      body: { file_1: file_1, file_2: file_2 }
    )

    expect(result).to be_success
  end
end