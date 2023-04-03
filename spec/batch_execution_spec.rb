RSpec.describe 'batch execution' do
  let(:client_classes) do
    3.times.map do |iteration|
      klass = Class.new(NxtHttpClient::Client)

      klass.class_exec(url) do |get_url|
        define_method(:call) do
          get(get_url) do |handler|
            handler.on(:success) do |_response|
              "response in client #{iteration + 1}"
            end
          end
        end

        configure do |config|
          config.base_url = nil
        end
      end

      klass
    end
  end

  let(:client_one) { client_classes[0].new }
  let(:client_two) { client_classes[1].new }
  let(:client_three) { client_classes[2].new }

  let(:ignore_around_callbacks) { false }
  let(:url) { http_stats_url('200') }

  subject do
    NxtHttpClient.execute_in_batch(client_three, client_one, client_two, ignore_around_callbacks: ignore_around_callbacks)
  end

  it 'executes multiple requests in batch and preserves the order of returned responses', :vcr_cassette do
    expect(subject).to eq(['response in client 3', 'response in client 1', 'response in client 2'])
  end
end
