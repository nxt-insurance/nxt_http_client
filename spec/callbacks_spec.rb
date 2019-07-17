require 'securerandom'

RSpec.describe NxtHttpClient::Client do
  context 'when the callback is a status code', :vcr_cassette do
    let(:request) { ::Typhoeus::Request.new("www.google.com", method: :get) }

    let(:client) do
      Class.new(NxtHttpClient::Client) do
        register_response_handler do |handler|
          handler.on(200) do |response|
            response.body
          end
        end
      end
    end

    subject do
      client.new
    end

    it 'runs the correct callback' do
      expect(subject.fire(request)).to include('Google')
    end
  end

  context 'when the callback is fuzzy', :vcr_cassette do
    let(:request) { ::Typhoeus::Request.new("www.google.com", method: :get) }

    let(:client) do
      Class.new(NxtHttpClient::Client) do
        register_response_handler do |handler|
          handler.on(200) do |response|
            response.body
          end
        end

        def call(request)
          fire(request) do |handler|
            handler.on!(200) do |response|
              response.body.length
            end
          end
        end
      end
    end

    subject do
      client.new
    end

    it 'runs the correct callback' do
      expect(subject.call(request)).to eq(11299)
    end
  end

  context 'special callbacks' do
    subject do
      client.new
    end

    context ':success', :vcr_cassette do
      let(:client) do
        Class.new(NxtHttpClient::Client) do
          register_response_handler do |handler|
            handler.on(:success) do |response|
              response.body
            end
          end
        end
      end

      let(:request) { ::Typhoeus::Request.new("www.google.com", method: :get) }

      it 'runs the success callback' do
        expect(subject.fire(request)).to include('Google')
      end
    end

    context ':error', :vcr_cassette do
      let(:client) do
        Class.new(NxtHttpClient::Client) do
          register_response_handler do |handler|
            handler.on(:error) do |response|
              raise StandardError, 'Response not successful'
            end
          end
        end
      end

      let(:request) { ::Typhoeus::Request.new("www.f193a3d484c97517369fa15e6e586b44.com", method: :get) }

      it 'runs the error callback' do
        expect { subject.fire(request) }.to raise_error StandardError, /Response not successful/
      end
    end

    context ':headers', :vcr_cassette do
      let(:client) do
        Class.new(NxtHttpClient::Client) do
          def initialize
            @headers = nil
          end

          attr_accessor :headers

          register_response_handler do |handler|
            handler.on(:headers) do |response|
              self.headers = response.headers
            end
          end
        end
      end

      let(:request) { ::Typhoeus::Request.new("www.google.com", method: :get) }

      it 'runs the on headers callback' do
        expect { subject.fire(request) }.to change { subject.headers }.from(nil)
      end
    end

    context ':body', :vcr_cassette do
      let(:client) do
        Class.new(NxtHttpClient::Client) do
          def initialize
            @chunks = StringIO.new
          end

          attr_accessor :chunks

          register_response_handler do |handler|
            handler.on(:body) do |chunk|
              chunks << 'body'
            end

            handler.on(:success) do |response|
              chunks.rewind
              chunks.read
            end
          end
        end
      end

      let(:request) { http_stats_request(200) }

      it 'runs the on body callback' do
        expect(subject.fire(request)).to eq('body')
      end
    end
  end
end
