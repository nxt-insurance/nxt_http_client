RSpec.describe NxtHttpClient::Client do
  context 'when the callback is a status code', :vcr_cassette do
    let(:client) do
      Class.new(NxtHttpClient::Client) do
        configure do |config|
          config.request_options = { followlocation: true }
          config.timeout_seconds(total: 60)
        end

        response_handler do |handler|
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
      expect(subject.fire('www.example.com')).to include('Example Domain')
    end
  end

  context 'when the callback is overwritten in the instance', :vcr_cassette do
    let(:client) do
      Class.new(NxtHttpClient::Client) do
        configure do
          config.timeout_seconds(total: 60)
        end

        response_handler do |handler|
          handler.on(200) do |response|
            raise StandardError, 'This should not happen!'
          end
        end

        def call
          fire('www.example.com') do |handler|
            handler.on!(200) do |response|
              response.body
            end
          end
        end
      end
    end

    subject do
      client.new
    end

    it 'runs the correct callback' do
      expect(subject.call).to include('Example Domain')
    end
  end

  context 'special callbacks' do
    subject do
      client.new
    end

    context ':success', :vcr_cassette do
      let(:client) do
        Class.new(NxtHttpClient::Client) do
          configure do
            config.timeout_seconds(total: 60)
          end

          response_handler do |handler|
            handler.on(:success) do |response|
              response.body
            end
          end
        end
      end

      it 'runs the success callback' do
        expect(subject.fire('www.example.com')).to include('Example Domain')
      end
    end

    context ':error', :vcr_cassette do
      let(:client) do
        Class.new(NxtHttpClient::Client) do
          def self.name
            'Test Client'
          end

          configure do
            config.timeout_seconds(total: 60)
          end

          response_handler do |handler|
            handler.on(:error) do |response|
              raise NxtHttpClient::Error.new(response, "#{self.class.name} => Response not successful")
            end
          end
        end
      end

      it 'runs the error callback' do
        expect {
          subject.fire('www.f193a3d484c97517369fa15e6e586b44.com')
        }.to raise_error NxtHttpClient::Error, 'Test Client => Response not successful'
      end
    end

    context ':headers', :vcr_cassette do
      let(:client) do
        Class.new(NxtHttpClient::Client) do
          def initialize
            @headers = nil
          end

          attr_accessor :headers

          configure do
            config.timeout_seconds(total: 60)
          end

          response_handler do |handler|
            handler.on(:headers) do |response|
              self.headers = response.headers
            end
          end
        end
      end

      it 'runs the on headers callback' do
        expect { subject.fire('www.example.com') }.to change { subject.headers }.from(nil)
      end
    end

    context ':body', :vcr_cassette do
      let(:client) do
        Class.new(NxtHttpClient::Client) do
          def initialize
            @chunks = StringIO.new
          end

          attr_accessor :chunks

          configure do
            config.timeout_seconds(total: 60)
          end

          response_handler do |handler|
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

      it 'runs the on body callback' do
        expect(subject.fire(http_status_url('200'))).to eq('body')
      end
    end
  end
end
