RSpec.describe NxtHttpClient::Client do
  let(:level_one) do
    Class.new(described_class) do
      register_response_handler do |handler|
        handler.on(200) do |response|
          '200 from level one class level'
        end

        handler.on(404) do |response|
          '404 from level one class level'
        end
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
        end
      end
    end
  end

  let(:level_four) do
    Class.new(level_three) do
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

  let(:request_200) { ::Typhoeus::Request.new("httpstat.us/200", method: :get) }
  let(:request_400) { ::Typhoeus::Request.new("httpstat.us/400", method: :get) }
  let(:request_401) { ::Typhoeus::Request.new("httpstat.us/401", method: :get) }

  context 'inherited response handler from parent class', :vcr_cassette do
    it 'inherits the response handler from the parent class' do
      expect(level_three.new.call(http_stats_url('404'))).to eq('404 from level one class level')
    end
  end

  context 'overwriting response handlers from the class' do
    it 'overwrites the handler from the class level', :vcr_cassette do
      expect(level_three.new.call(http_stats_url('200'))).to eq('200 from level three')
    end

    it 'does not touch the callbacks of the super class' do
      expect { level_two }.to_not change { level_one.response_handler.send(:callbacks) }
      expect { level_three }.to_not change { level_one.response_handler.send(:callbacks) }
      expect { level_three }.to_not change { level_two.response_handler.send(:callbacks) }
    end
  end

  context 'fuzzy matcher in subclass', :vcr_cassette do
    it 'matches everything not matched in the super classes' do
      expect(level_three.new.call(http_stats_url('401'))).to eq('4** from level three')
      expect(level_three.new.fresh_call(http_stats_url('401'))).to eq('fresh 4** from level three')
      expect(level_three.new.fresh_call(http_stats_url('404'))).to eq('fresh 4** from level three')
    end
  end

  context 'resetting the response handler on class level', :vcr_cassette do
    it 'does not inherit callbacks from the super class' do
      expect(level_four.new.fire(http_stats_url('404'))).to eq('4** from level four class level')
    end
  end
end
