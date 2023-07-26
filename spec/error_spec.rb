RSpec.describe NxtHttpClient::Error do
  context 'when the request is blank somehow' do
    subject do
      described_class.new(nil)
    end

    it 'responds to all methods' do
      expect(subject.body).to be_nil
      expect(subject.url).to eq("/dev/null")
      expect(subject.request).to be_a(Typhoeus::Request)
      expect(subject.request_options).to eq({})
      expect(subject.request_headers).to eq({})
      expect(subject.response_options).to eq({})
      expect(subject.response_headers).to eq({})
      expect(subject.response_content_type).to be_nil
      expect(subject.timed_out?).to be(false)
      expect(subject.status_message).to be(nil)
    end
  end

  context 'when initialized with a real response' do
    let(:client) do
      Class.new(NxtHttpClient::Client) do
        configure do |config|
          config.timeout_seconds(total: 60)
        end

        response_handler do |handler|
          handler.on(:error) do |response|
            NxtHttpClient::Error.new(response)
          end
        end
      end
    end

    subject do
      client.new.fire(http_status_url('503'))
    end

    it 'responds to all methods', :vcr_cassette do
      expect(subject.body).to eq('503 Service Unavailable')
      expect(subject.url).to eq('httpstat.us/503')
      expect(subject.request).to be_a(Typhoeus::Request)
      expect(subject.request_options).to include('headers'=>{}, 'cache'=>false)
      expect(subject.request_headers).to eq({})
      expect(subject.response_options).to include(
        'code' => 503,
        'status_message' => 'Service Unavailable',
        'body' => '503 Service Unavailable'
      )
      expect(subject.response_headers).to include('Content-Type' => 'text/plain; charset=utf-8')
      expect(subject.response_content_type).to eq('text/plain; charset=utf-8')

      expect(subject.to_h.keys).to match_array(
        %i[id url response_code request_options response_headers request_headers body x_request_id]
      )
      expect(subject.timed_out?).to be(false)
      expect(subject.response_code).to be(503)
      expect(subject.status_message).to eq('Service Unavailable')
    end
  end

  context 'content type json' do
    let(:url) { 'http://echo.jsontest.com/key/value/one/two' }

    subject do
      client.new.get(url)
    end

    context 'when the response contains invalid json' do
      let(:client) do
        Class.new(NxtHttpClient::Client) do
          configure do
            config.timeout_seconds(total: 60)
          end

          response_handler do |handler|
            handler.on(:success) do |response|
              response.define_singleton_method :body do
                'broken json'
              end

              NxtHttpClient::Error.new(response)
            end
          end
        end
      end

      it 'returns the unparsed body', :vcr_cassette do
        expect(subject.body).to eq('broken json')
      end
    end

    context 'when the response is valid json' do
      let(:client) do
        Class.new(NxtHttpClient::Client) do
          configure do
            config.timeout_seconds(total: 60)
          end

          response_handler do |handler|
            handler.on(:success) do |response|
              NxtHttpClient::Error.new(response)
            end
          end
        end
      end

      it 'parses the json body', :vcr_cassette do
        expect(subject.body).to eq("one" => "two", "key" => "value")
      end
    end
  end
end
