module HttpStatsHelper
  def http_stats_url(status)
    "httpstat.us/#{status}"
  end

  def http_stats_request(status, opts = {})
    ::Typhoeus::Request.new(http_stats_url(status), **opts)
  end
end

RSpec.configure do |config|
  config.include HttpStatsHelper
end
