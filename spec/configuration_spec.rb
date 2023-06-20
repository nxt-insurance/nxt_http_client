RSpec.describe NxtHttpClient::Client do

  let(:level_one) do
    Class.new(described_class) do
      configure do |config|
        config.base_url = 'httpstat.us'
        config.request_options = { method: :get }
      end

      response_handler do |handler|
        handler.on(200) do |response|
          response.request.original_options.symbolize_keys
        end

        handler.on('400') do |response|
          response.request.base_url
        end
      end

      def call(status)
        fire(status)
      end
    end
  end

  subject do
    level_one.new
  end

  describe '.default_request_options' do
    it 'builds the request with the default options', :vcr_cassette do
      expect(subject.call('200')).to eq(method: :get, cache: false, headers: {})
    end
  end

  describe '.base_url' do
    it 'builds the request with the base url', :vcr_cassette do
      expect(subject.call('400')).to eq("httpstat.us/400")
    end
  end

  describe '.json_headers' do
    it 'sends the request with JSON data', vcr_cassette: { match_requests_on: [:uri, :method, :headers, :body_as_json] } do
      client = NxtHttpClient::Client.make do
        configure do |config|
          config.base_url = 'https://postman-echo.com'
          config.json_headers = true
        end
      end

      request = client.build_request('')
      expect(request.options[:headers]).to match(hash_including(
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
      ))
      response = client.post('post', body: { some: 'thing' })
      expect(JSON(response.body)['json']).to eq(
        'some' => 'thing',
      )
    end
  end

  describe '.json_response' do
    it 'parses the response body as JSON', vcr_cassette: { match_requests_on: [:uri, :method, :headers, :body_as_json] } do
      client = NxtHttpClient::Client.make do
        configure do |config|
          config.base_url = 'https://postman-echo.com'
          config.json_headers = true
          config.json_response = true
        end
      end

      request = client.build_request('')
      expect(request.options[:headers]).to match(hash_including(
        'Accept' => 'application/json',
      ))
      response = client.post('post', body: { some: 'thing' })
      expect(response.body).to be_a(Hash)
      expect(response.body['json']).to eq(
        'some' => 'thing',
      )
    end
  end

  describe '.bearer_auth' do
    it 'sets the correct Authorization header', vcr_cassette: { match_requests_on: [:uri, :method, :headers] } do
      client = NxtHttpClient::Client.make do
        configure do |config|
          config.base_url = 'https://postman-echo.com'
          config.json_headers = true
          config.bearer_auth = 'mytoken'
        end
      end

      response = client.post('post')
      expect(JSON(response.body)['headers']).to match(hash_including(
        'authorization' => 'Bearer mytoken',
      ))
    end
  end

  describe '.basic_auth' do
    it 'sets the correct Authorization header', vcr_cassette: { match_requests_on: [:uri, :method, :headers] } do
      client = NxtHttpClient::Client.make do
        configure do |config|
          config.base_url = 'https://postman-echo.com'
          config.json_headers = true
          config.basic_auth = 'myusername', 'mypassword'
        end
      end

      response = client.post('post')
      expect(JSON(response.body)['headers']).to match(hash_including(
        'authorization' => 'Basic ' + Base64.strict_encode64('myusername:mypassword'),
      ))
    end
  end

  describe '.timeout' do
    around do |example|
      # Timeout doesn't work when replaying a VCR request
      WebMock.allow_net_connect!
      VCR.turned_off { example.run }
      WebMock.disable_net_connect!
    end

    it 'sets the timeout correctly' do
      client = NxtHttpClient::Client.make do
        configure do |config|
          config.base_url = 'httpstat.us?sleep=1000'
          config.timeout_seconds(total: 0.5, connect: 0.2)
        end
      end

      expect(client.build_request('').options).to match(hash_including(
        timeout: 0.5,
        connecttimeout: 0.2,
      ))
    end
  end

  context 'inheritance' do
    let(:level_one) do
      Class.new(described_class) do
        configure do |config|
          config.base_url = 'httpstat.us'
          config.request_options.deep_merge!(headers: { token: 'level one token'})
        end
      end
    end

    let(:level_two) do
      Class.new(level_one) do
        configure do |config|
          config.base_url = 'httpstat.us'
          config.request_options.deep_merge!(headers: { token: 'level two token'})
        end
      end
    end

    let(:level_three) do
      Class.new(level_one) do
        configure do |config|
          config.base_url = 'httpstat.us'
          config.request_options.deep_merge!(headers: { token: 'level three token'})
        end
      end
    end

    it 'dups the configuration' do
      expect(level_one.config.request_options).to eq({"headers"=>{"token"=>"level one token"}})
      expect(level_three.config.request_options).to eq({"headers"=>{"token"=>"level three token"}})
      expect(level_one.config.request_options).to eq({"headers"=>{"token"=>"level one token"}})
      expect(level_two.config.request_options).to eq({"headers"=>{"token"=>"level two token"}})
      expect(level_one.config.request_options).to eq({"headers"=>{"token"=>"level one token"}})
    end
  end
end
