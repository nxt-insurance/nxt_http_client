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
        response_handler do |handler|
          handler.on(200) do |response|
            response
          end
        end

        configure do |config|
          config.request_options = { cache: :thread }
          config.x_request_id_proc = -> { Thread.current.object_id }
          config.timeout_seconds(total: 90)
        end
      end
    end

    it 'caches per within the current thread' do
      expect(subject.fire('www.example.com')).to_not be_cached
      expect(subject.fire('www.example.com')).to be_cached
      expect(subject.fire('www.example.com')).to be_cached

      Thread.new { expect(subject.fire('www.example.com')).to_not be_cached }.join
      Thread.new { expect(subject.fire('www.example.com')).to_not be_cached }.join
    end
  end

  context 'is switched off by default' do
    let(:client) do
      Class.new(NxtHttpClient::Client) do
        response_handler do |handler|
          handler.on(200) do |response|
            response
          end
        end

        configure do |config|
          config.x_request_id_proc = -> { Thread.current.object_id }
          config.timeout_seconds(total: 90)
        end
      end
    end

    it 'is switched off by default' do
      5.times do
        expect(subject.fire('www.example.com')).to_not be_cached
      end
    end

    it 'can be switched on per request' do
      # we need to post here in order to not collide with cached content since we are in the same thread as the example above
      expect(subject.post('www.example.com', cache: :thread)).to_not be_cached
      expect(subject.post('www.example.com', cache: :thread)).to be_cached
      expect(subject.post('www.example.com', cache: :thread)).to be_cached

      # not yet cached and thus does not hit the cache the first time
      Thread.new { expect(subject.fire('www.example.com', cache: :thread)).to_not be_cached }.join
      Thread.new { expect(subject.fire('www.example.com', cache: :thread)).to_not be_cached }.join
    end
  end
end
