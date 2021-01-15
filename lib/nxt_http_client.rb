require 'active_support/all'
require 'typhoeus'
require 'nxt_registry'
require 'parallel'

require 'nxt_http_client/version'
require 'nxt_http_client/headers'
require 'nxt_http_client/concurrent'
require 'nxt_http_client/response_handler'
require 'nxt_http_client/config'
require 'nxt_http_client/undefined'
require 'nxt_http_client/logger'
require 'nxt_http_client/fire_callbacks'
require 'nxt_http_client/client_dsl'
require 'nxt_http_client/client'
require 'nxt_http_client/error'

module NxtHttpClient
  def parallel(**opts, &block)
    NxtHttpClient::Concurrent.new.parallel(**opts, &block)
  end

  module_function :parallel
end
