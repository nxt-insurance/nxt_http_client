VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false
  config.ignore_localhost = true
  config.default_cassette_options = {
    decode_compressed_response: true,
    match_requests_on: [:method, :uri],
    # record: :once,
    update_content_length_header: true
  }
end
