NxtVcrHarness.enable_vcr_tag(default_cassette_options: { allow_unused_http_interactions: false })
NxtVcrHarness.track_cassettes_if(ENV['TRACK_VCR_CASSETTES'])
NxtVcrHarness.enable_vcr_cassette_helper

module VcrHelper
  def let_vcr_cassette(example, name, opts: { allow_unused_http_interactions: true }, &block)
    with_vcr_cassette(example, opts.merge(suffix: name), &block)
  end
end

RSpec.configure do |config|
  config.include VcrHelper
end
