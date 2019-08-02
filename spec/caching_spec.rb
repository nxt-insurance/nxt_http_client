RSpec.describe NxtHttpClient::Client do
  around do |example|
    # It seems that only real requests can be cached - not those replayed by VCR
    WebMock.allow_net_connect!
    VCR.turned_off do
      example.run
    end
    WebMock.disable_net_connect!
  end

  subject do
    client.new
  end

  context 'when caching was switched on' do
    let(:client) do
      Class.new(NxtHttpClient::Client) do
        register_response_handler do |handler|
          handler.on(200) do |response|
            response
          end
        end

        register_defaults do |defaults|
          defaults.request_options = { cache: true }
        end
      end
    end

    it 'caches per within the current thread' do
      expect(subject.fire(http_stats_url('200'))).to_not be_cached
      expect(subject.fire(http_stats_url('200'))).to be_cached
      expect(subject.fire(http_stats_url('200'))).to be_cached

      Thread.new { expect(subject.fire(http_stats_url('200'))).to_not be_cached }.join
      Thread.new { expect(subject.fire(http_stats_url('200'))).to_not be_cached }.join
    end
  end

  context 'is switched off per default' do
    let(:client) do
      Class.new(NxtHttpClient::Client) do
        register_response_handler do |handler|
          handler.on(200) do |response|
            response
          end
        end
      end
    end

    it 'is switched off per default' do
      5.times do
        expect(subject.fire(http_stats_url('200'))).to_not be_cached
      end
    end
  end
end
