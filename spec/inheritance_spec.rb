RSpec.describe NxtHttpClient::Client do
  let(:level_one) do
    Class.new(described_class) do
      def initialize
        @log = []
      end

      attr_accessor :log

      configure do |config|
        config.base_url = 'httpstat.us'
        config.request_options = {
          headers: { Accept: "text/html", Token: 'my custom token' }
        }
      end

      register_response_handler do |handler|
        handler.on(200) do |response|
          '200 from level one class level'
        end

        handler.on(404) do |response|
          '404 from level one class level'
        end
      end

      before_fire do |request|
        log << { level_one: request.url }
      end

      after_fire do |request, response, result|
        log << { level_one: response.code }
        result
      end
    end
  end

  let(:level_two) do
    Class.new(level_one) do
      register_response_handler do |handler|
        handler.on(201) do |response|
          '201 from level one class level'
        end
      end

      def call(url)
        fire(url) do |handler|
          handler.on!(200) do |response|
            '200 from level two'
          end

          handler.on(401) do |respons|
            'Not Authorized from level two'
          end
        end
      end
    end
  end

  let(:level_three) do
    Class.new(level_two) do
      def call(url)
        fire(url) do |handler|
          handler.on!(200) do |response|
            '200 from level three'
          end

          handler.on('4**') do |response|
            '4** from level three'
          end
        end
      end

      def fresh_call(url)
        fire(url, response_handler: NxtHttpClient::ResponseHandler.new) do |handler|
          handler.on(200) do |response|
            'fresh 200 from level three'
          end

          handler.on('4**') do |response|
            'fresh 4** from level three'
          end

          handler.on('5**') do |response|
            raise StandardError, 'Raisor blade'
          end
        end
      end

      before_fire do |request, response_handler|
        log << { level_three: request.url }
      end

      after_fire do |request, response, result, error|
        log << { level_three: response.code }

        if error
          raise error
        else
          result
        end
      end
    end
  end

  let(:level_four) do
    Class.new(level_three) do
      configure do |config|
        config.base_url = nil
        config.request_options.deep_merge(headers: { Token: 'deep merge' })
        config.x_request_id_proc = -> { 'my id' }
      end

      register_response_handler(NxtHttpClient::ResponseHandler.new) do |handler|
        handler.on(200) do |response|
          '200 from level four class level'
        end

        handler.on('4**') do |response|
          '4** from level four class level'
        end
      end
    end
  end

  context 'headers' do
    let(:level_four_client) { level_four.new }

    let(:expected_request_options) { { Accept: 'text/html', Token: 'my custom token' }.with_indifferent_access }
    let(:headers) { { headers: expected_request_options.merge('X-Request-ID': 'my id') }.with_indifferent_access }

    it 'deep merges headers from super classes', :vcr_cassette do
      expect(
        level_four_client.class.default_config.request_options.with_indifferent_access
      ).to eq(
        'headers' => expected_request_options
      )

      result = level_four_client.put(http_stats_url('503'))

      expect(result.request.original_options[:headers]).to eq(headers[:headers])
    end
  end

  context 'inherited response handler from parent class', :vcr_cassette do
    it 'inherits the response handler from the parent class' do
      expect(level_three.new.call('404')).to eq('404 from level one class level')
    end
  end

  context 'overwriting response handlers from the class' do
    it 'overwrites the handler from the class level', :vcr_cassette do
      expect(level_three.new.call('200')).to eq('200 from level three')
    end

    it 'does not touch the callbacks of the super class' do
      expect { level_two }.to_not change { level_one.response_handler.send(:callbacks) }
      expect { level_three }.to_not change { level_one.response_handler.send(:callbacks) }
      expect { level_three }.to_not change { level_two.response_handler.send(:callbacks) }
    end
  end

  context 'fuzzy matcher in subclass', :vcr_cassette do
    it 'matches everything not matched in the super classes' do
      expect(level_three.new.call('401')).to eq('4** from level three')
      expect(level_three.new.fresh_call('401')).to eq('fresh 4** from level three')
      expect(level_three.new.fresh_call('404')).to eq('fresh 4** from level three')
    end
  end

  context 'resetting the response handler on class level', :vcr_cassette do
    it 'does not inherit callbacks from the super class' do
      expect(level_four.new.fire(http_stats_url('404'))).to eq('4** from level four class level')
    end
  end

  describe '#before_fire' do
    let(:level_two_client) { level_two.new }
    let(:level_three_client) { level_three.new }

    it 'calls the correct callback', :vcr_cassette do
      expect { level_two_client.call('401') }.to change { level_two_client.log }
      expect(level_two_client.log.first).to eq(level_one: "httpstat.us/401")

      expect { level_three_client.call('200') }.to change { level_three_client.log }
      expect(level_three_client.log.first).to eq(level_three: "httpstat.us/200")
    end
  end

  describe '#after_fire' do
    let(:level_two_client) { level_two.new }
    let(:level_three_client) { level_three.new }

    it 'calls the correct callback', :vcr_cassette do
      expect { level_two_client.call('401') }.to change { level_two_client.log }
      expect(level_two_client.log.last).to eq(level_one: 401)

      expect { level_three_client.fresh_call('200') }.to change { level_three_client.log }
      expect(level_three_client.log.last).to eq(level_three: 200)
    end

    context 'when there was an error' do
      it 'passes the error to the callback', :vcr_cassette do
        expect { level_three.new.fresh_call('503') }.to raise_error StandardError, 'Raisor blade'
      end
    end
  end
end
