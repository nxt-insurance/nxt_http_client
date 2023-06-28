module HttpStatusHelper
  def http_status_url(status)
    "httpstat.us/#{status}"
  end
end

RSpec.configure do |config|
  config.include HttpStatusHelper
end
