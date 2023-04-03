RSpec.describe NxtHttpClient::Client::BatchPatch do
  let(:client_one_class) do
    Class.new(NxtHttpClient::Client) do
      attr_reader :cache

      def initialize
        @cache = []
      end

      configure do |config|
        config.base_url = nil
      end

      response_handler(NxtHttpClient::ResponseHandler.new) do |handler|
        handler.on(200) do |_response|
          'response in client 1'
        end
      end

      before_fire do |_client, _request, _response_handler|
        cache << 'before fire callback'
      end

      after_fire do |_client, _request, _response, result, _error|
        cache << 'after fire callback'
        result
      end
    end
  end

  let(:client_two_class) do
    Class.new(NxtHttpClient::Client) do
      attr_reader :cache

      def initialize
        @cache = []
      end

      configure do |config|
        config.base_url = nil
      end

      response_handler(NxtHttpClient::ResponseHandler.new) do |handler|
        handler.on(200) do |_response|
          'response in client 2'
        end
      end

      before_fire do |_client, _request, _response_handler|
        cache << 'before fire callback'
      end

      after_fire do |_client, _request, _response, result, _error|
        cache << 'after fire callback'
        result
      end
    end
  end

  subject do
    client_instances = [client_one, client_two]

    client_map = Hash.new do |hash, key|
      hash[key] = { request: nil, error: nil, result: nil }
    end

    client_instances.each do |client|
      client.assign_batch_data(client_map[client], ignore_around_callbacks)
    end

    hydra = Typhoeus::Hydra.new

    client_instances.each do |client|
      client.get(url).tap do |request|
        hydra.queue(request)
      end
    end

    hydra.run

    client_map.map do |client, response_data|
      client.finish(response_data[:request], response_data[:result], response_data[:error])
    end
  end

  let(:client_one) { client_one_class.new }
  let(:client_two) { client_two_class.new }

  let(:ignore_around_callbacks) { false }
  let(:url) { http_stats_url('200') }

  before do
    [client_one, client_two].each { _1.singleton_class.include(NxtHttpClient::Client::BatchPatch) }
  end

  context 'when around_fire callbacks are not defined', :vcr_cassette do
    it 'executes multiple requests in batch' do
      expect(subject).to eq(['response in client 1', 'response in client 2'])
      [client_one, client_two].each do |client|
        expect(client.cache).to eq(['before fire callback', 'after fire callback'])
      end
    end
  end

  context 'when around_fire callbacks are defined' do
    before do
      [[client_one_class, '1'], [client_two_class, '2']].each do |client_class, client_id|
        client_class.class_eval do
          around_fire do |_client, _request, _response_handler, _fire|
            callback_map["client #{client_id}"] << 'around fire callback'
          end
        end
      end
    end

    context 'when callback ignore is not acknowledged', :vcr_cassette do
      let(:ignore_around_callbacks) { false }

      it 'does not allow execution' do
        expect { subject }.to raise_error(ArgumentError, /`around_fire` callbacks are not supported when firing batches/)
      end
    end

    context 'when callback ignore is acknowledged', :vcr_cassette do
      let(:ignore_around_callbacks) { true }

      it 'allows execution without running around callbacks' do
        expect(subject).to eq(['response in client 1', 'response in client 2'])
        [client_one, client_two].each do |client|
          expect(client.cache).to eq(['before fire callback', 'after fire callback'])
        end
      end
    end
  end
end
