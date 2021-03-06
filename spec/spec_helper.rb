require 'bundler/setup'
require 'vcr'
require 'nxt_vcr_harness'
require 'nxt_http_client'
require 'pry'
require 'redis'
require 'typhoeus/cache/redis'
require 'timecop'

require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

Dir['spec/support/**/*.rb'].each { |f| require "./#{f}" }

NxtHttpClient::REDIS_TEST_DB = Redis.new(db: 5)
::Typhoeus::Config.cache = ::Typhoeus::Cache::Redis.new(NxtHttpClient::REDIS_TEST_DB, default_ttl: 60)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
