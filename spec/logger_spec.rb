RSpec.describe NxtHttpClient::Logger do
  let(:level_one) do
    Class.new(NxtHttpClient::Client) do
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

        handler.on(:error) do |response|
          raise NxtHttpClient::Error.new(response)
        end
      end

      def self.logs
        @logs ||= {}
        @logs[name] ||= []
        @logs[name]
      end

      log do |info|
        logs << info.to_h
      end
    end
  end

  let(:client) { level_one.new }
  let(:now) { Time.current }

  before do
    Timecop.freeze(now) do
      4.times { client.get('200') }
    end
  end

  it 'logs', :vcr_cassette do
    expect(level_one.logs.count). to eq(4)

    expect(level_one.logs).to all(
      match(
        client: be_a(level_one),
        started_at: now.to_i * 1000,
        request: be_a(Typhoeus::Request),
        response: be_a(Typhoeus::Response),
        finished_at: now.to_i * 1000,
        http_status: 200,
        elapsed_time_in_milliseconds: 0
      )
    )
  end

  context 'inheritance' do
    let(:level_two) do
      Class.new(level_one)
    end

    let(:level_three) do
      Class.new(level_two) do
        def self.logs
          @logs ||= []
        end

        log do |_|
          logs << '*'
        end
      end
    end

    context 'when logger is inherited', :vcr_cassette do
      it 'logs with the inherited logger' do
        expect { 2.times { level_two.new.get('200') } }.to change { level_one.logs.size }.by(2)
      end
    end

    context 'when logger is redefined', :vcr_cassette do
      it 'logs with the own logger' do
        expect { 2.times { level_three.new.get('200') } }.to change { level_three.logs.size }.by(2)
        expect(level_three.logs).to eq(%w[* *])
      end
    end
  end

  let(:http_status) { 503 }
  let(:log_size) { client.class.logs.count }

  context 'when the request errors' do
    before { log_size }

    it 'does log the errored request', :vcr_cassette do
      expect { client.get(http_status) }.to raise_error(NxtHttpClient::Error)
      expect(client.class.logs.count).to eq(log_size + 1 )
      expect(client.class.logs.last[:http_status]).to eq(http_status)
    end
  end
end
