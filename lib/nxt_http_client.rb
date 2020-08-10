require 'active_support/all'
require 'typhoeus'
require 'nxt_registry'

require 'nxt_http_client/version'
require 'nxt_http_client/response_handler'
require 'nxt_http_client/default_config'
require 'nxt_http_client/client_dsl'
require 'nxt_http_client/client'
require 'nxt_http_client/error'

module NxtHttpClient
  class Error < StandardError; end
end
