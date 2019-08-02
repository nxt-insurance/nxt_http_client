RSpec.configure do |config|
  config.around(:each) do |each|
    NxtHttpClient::REDIS_TEST_DB.flushall
    each.run
    NxtHttpClient::REDIS_TEST_DB.flushall
  end
end
