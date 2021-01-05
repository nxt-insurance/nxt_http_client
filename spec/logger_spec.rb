RSpec.describe NxtHttpClient::Logger do
  let(:test_class) do
    Class.new(NxtHttpClient::Client) do
      LOG = []

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

      self.logger = -> (info) { LOG << info.to_h }
    end
  end

  let(:client) { test_class.new }
  let(:now) { Time.current }

  before do
    Timecop.freeze(now) do
      client.get('200')
      client.get('200')
      client.get('200')
      client.get('200')
    end
  end

  it 'logs', :vcr_cassette do
    expect(LOG.count). to eq(4)

    expect(LOG).to all(
      match(
        client: be_a(test_class),
        started_at: now.to_i * 1000,
        request: be_a(Typhoeus::Request),
        response: be_a(Typhoeus::Response),
        finished_at: now.to_i * 1000,
        http_status: 200
      )
    )
  end
end
