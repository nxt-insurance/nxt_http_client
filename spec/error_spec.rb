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
      expect(subject.timed_out?).to be_falsey
      expect(subject.status_message).to be_nil
      expect(subject.response_code).to be_zero
    end
  end

  context 'when the response is a empty string' do
    subject do
      described_class.new('')
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
      expect(subject.timed_out?).to be_falsey
      expect(subject.status_message).to be_nil
      expect(subject.response_code).to be_zero
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

  describe '#to_h credential redaction' do
    before { stub_request(:get, 'http://creds.test/').to_return(status: 401) }

    def to_h_for(&setup)
      client = NxtHttpClient::Client.make do
        configure do |config|
          config.base_url = 'http://creds.test'
          config.raise_error_taxonomy = true
          config.timeout_seconds(total: 60)
          setup.call(config)
        end
      end

      client.get('')
    rescue NxtHttpClient::Error => error
      error.to_h
    end

    it 'redacts the bearer Authorization header' do
      hash = to_h_for { |config| config.bearer_auth = 'super-secret-token' }

      expect(hash[:request_headers]['Authorization']).to eq('[REDACTED]')
      expect(hash[:request_options]['headers']['Authorization']).to eq('[REDACTED]')
    end

    it 'redacts the basic-auth userpwd' do
      hash = to_h_for { |config| config.basic_auth = { username: 'user', password: 'pass' } }

      expect(hash[:request_options]['userpwd']).to eq('[REDACTED]')
    end
  end

  describe '.from_response' do
    def network_response(return_code)
      Typhoeus::Response.new(code: 0, return_code: return_code, mock: true)
    end

    def status_response(code)
      Typhoeus::Response.new(code: code, return_code: :ok, mock: true)
    end

    {
      operation_timedout: NxtHttpClient::Error::Timeout,
      couldnt_connect: NxtHttpClient::Error::ConnectionFailed,
      couldnt_resolve_host: NxtHttpClient::Error::NameResolutionError,
      couldnt_resolve_proxy: NxtHttpClient::Error::NameResolutionError,
      ssl_connect_error: NxtHttpClient::Error::TlsError,
      ssl_cipher: NxtHttpClient::Error::TlsError,
      peer_failed_verification: NxtHttpClient::Error::CertificateError,
      ssl_cacert_badfile: NxtHttpClient::Error::CertificateError,
      some_other_curl_failure: NxtHttpClient::Error::NetworkError,
    }.each do |return_code, expected_class|
      it "maps return_code #{return_code} to #{expected_class}" do
        expect(NxtHttpClient::Error.from_response(network_response(return_code))).to be_an_instance_of(expected_class)
      end
    end

    {
      400 => NxtHttpClient::Error::BadRequest,
      401 => NxtHttpClient::Error::Unauthorized,
      403 => NxtHttpClient::Error::Forbidden,
      404 => NxtHttpClient::Error::NotFound,
      409 => NxtHttpClient::Error::ClientError,    # unmapped 4xx falls back to ClientError
      422 => NxtHttpClient::Error::UnprocessableEntity,
      429 => NxtHttpClient::Error::TooManyRequests,
      500 => NxtHttpClient::Error::ServerError,
      503 => NxtHttpClient::Error::ServerError,
    }.each do |code, expected_class|
      it "maps status #{code} to #{expected_class}" do
        expect(NxtHttpClient::Error.from_response(status_response(code))).to be_an_instance_of(expected_class)
      end
    end

    it 'returns the base Error for an unmapped (3xx) response' do
      expect(NxtHttpClient::Error.from_response(status_response(304))).to be_an_instance_of(NxtHttpClient::Error)
    end
  end

  describe 'retry hierarchy' do
    it 'groups the retryable errors under NetworkError / ServerError' do
      [NxtHttpClient::Error::Timeout, NxtHttpClient::Error::ConnectionFailed,
       NxtHttpClient::Error::NameResolutionError, NxtHttpClient::Error::TlsError].each do |klass|
        expect(klass.new(nil)).to be_a(NxtHttpClient::Error::NetworkError)
      end
    end

    it 'excludes CertificateError and 4xx from the retryable bases' do
      expect(NxtHttpClient::Error::CertificateError.new(nil)).not_to be_a(NxtHttpClient::Error::NetworkError)
      expect(NxtHttpClient::Error::TooManyRequests.new(nil)).not_to be_a(NxtHttpClient::Error::ServerError)
      expect(NxtHttpClient::Error::UnprocessableEntity.new(nil)).to be_a(NxtHttpClient::Error::ClientError)
    end

    it 'keeps every subclass rescuable as the base NxtHttpClient::Error' do
      [NxtHttpClient::Error::NetworkError, NxtHttpClient::Error::ClientError,
       NxtHttpClient::Error::ServerError, NxtHttpClient::Error::CertificateError].each do |klass|
        expect(klass.new(nil)).to be_a(NxtHttpClient::Error)
      end
    end
  end
end
