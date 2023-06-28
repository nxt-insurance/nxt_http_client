RSpec.describe NxtHttpClient::Client::BatchPatch do
  let(:client_classes) do
    2.times.map do |iteration|
      Class.new(NxtHttpClient::Client) do
        attr_reader :cache, :specified_url

        def initialize
          @cache = []
        end

        configure do |config|
          config.base_url = nil
        end

        response_handler(NxtHttpClient::ResponseHandler.new) do |handler|
          handler.on(200) do |_response|
            "response in client #{iteration + 1}"
          end

          handler.on(400) do |_response|
            raise StandardError, "400 error"
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
  end

  subject do
    client_instances, client_urls = [client_one, client_two].transpose

    client_map = Hash.new do |hash, key|
      hash[key] = { request: nil, error: nil, result: nil }
    end

    client_instances.each do |client|
      client.assign_batch_data(client_map[client], ignore_around_callbacks)
    end

    hydra = Typhoeus::Hydra.new

    client_instances.zip(client_urls).each do |(client, url)|
      client.get(url).tap do |request|
        hydra.queue(request)
      end
    end

    hydra.run

    client_map.map do |client, response_data|
      client.finish(response_data[:request], response_data[:result], response_data[:error], raise_errors: raise_errors)
    end
  end

  let(:client_one) { [client_classes[0].new, http_status_url(200)] }
  let(:client_two) { [client_classes[1].new, http_status_url(200)] }

  let(:ignore_around_callbacks) { false }
  let(:raise_errors) { true }

  before do
    [client_one, client_two].each { |(instance, _)| instance.singleton_class.include(NxtHttpClient::Client::BatchPatch) }
  end

  context 'when around_fire callbacks are not defined', :vcr_cassette do
    it 'executes multiple requests in batch' do
      expect(subject).to eq(['response in client 1', 'response in client 2'])
      [client_one, client_two].each do |(client, _)|
        expect(client.cache).to eq(['before fire callback', 'after fire callback'])
      end
    end
  end

  context 'when around_fire callbacks are defined' do
    before do
      client_classes.each_with_index do |client_class, _client_id|
        client_class.class_eval do
          around_fire do |_client, _request, _response_handler, fire|
            cache << 'around fire callback'
            fire.call
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
        [client_one, client_two].each do |(client, _)|
          expect(client.cache).to eq(['before fire callback', 'after fire callback'])
        end
      end
    end
  end

  context 'when a request raises an error', :vcr_cassette do
    let(:client_one) { [client_classes[0].new, http_status_url(200)] }
    let(:client_two) { [client_classes[1].new, http_status_url(400)] }

    context 'when raise_errors is set to true', :vcr_cassette do
      let(:raise_errors) { true }

      it 'executes the requests and raises the first encountered error' do
        expect { subject }.to raise_error(StandardError, /400 error/)
      end
    end

    context 'when raies_errors is set to false', :vcr_cassette do
      let(:raise_errors) { false }

      it 'executes the requests and returns the error as a member of an array of responses' do
        expect(subject).to contain_exactly('response in client 1', instance_of(StandardError))
      end
    end
  end
end
