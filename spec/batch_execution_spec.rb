RSpec.describe 'batch execution' do
  let(:client_classes) do
    3.times.map do |iteration|
      klass = Class.new(NxtHttpClient::Client)

      klass.class_exec(iteration) do |current_iteration|
        attr_reader :specified_url

        def initialize(url)
          @specified_url = url
        end

        define_method(:call) do
          get(specified_url) do |handler|
            handler.on(:success) do |_response|
              "response in client #{current_iteration + 1}"
            end

            handler.on(400) do |_response|
              raise StandardError, '400 error'
            end

            handler.on(404) do |_response|
              raise StandardError, '404 error'
            end
          end
        end

        configure do |config|
          config.base_url = nil
          config.timeout_seconds(total: 60)
        end
      end

      klass
    end
  end

  let(:client_one) { client_classes[0].new(http_status_url('200')) }
  let(:client_two) { client_classes[1].new(http_status_url('200')) }
  let(:client_three) { client_classes[2].new(http_status_url('200')) }

  let(:ignore_around_callbacks) { false }
  let(:raise_errors) { true }
  let(:url) { http_status_url('200') }

  subject do
    NxtHttpClient.execute_in_batch(
      client_three,
      client_one,
      client_two,
      ignore_around_callbacks: ignore_around_callbacks,
      raise_errors: raise_errors
    )
  end

  it 'executes multiple requests in batch and preserves the order of returned responses', :vcr_cassette do
    expect(subject).to eq(['response in client 3', 'response in client 1', 'response in client 2'])
  end

  context 'when one of the requests raises an error' do
    let(:client_one) { client_classes[0].new(http_status_url('400')) }
    let(:client_two) { client_classes[1].new(http_status_url('404')) }
    let(:client_three) { client_classes[2].new(http_status_url('200')) }

    context 'with raise_errors argument set to true', :vcr_cassette do
      let(:raise_errors) { true }

      it 'executes the requests and raises the first encountered error' do
        expect { subject }.to raise_error(StandardError, /400 error/)
      end
    end

    context 'with raise_errors argument set to false', :vcr_cassette do
      let(:raise_errors) { false }

      it 'executes the requests and returns the errors as members of the response array' do
        expect(subject).to contain_exactly('response in client 3', instance_of(StandardError), instance_of(StandardError))
      end
    end
  end
end
