module NxtHttpClient
  class Client
    module BatchPatch
      attr_reader :callback_map, :ignore_around_callbacks

      def assign_batch_data(callback_map, ignore_around_callbacks)
        @callback_map = callback_map
        @ignore_around_callbacks = ignore_around_callbacks
      end

      def fire(url = '', **opts, &block)
        response_handler = build_response_handler(opts[:response_handler], &block)
        request = build_request(url, **opts.except(:response_handler))
        callback_map[:request] = request

        setup_on_headers_callback(request, response_handler)
        setup_on_body_callback(request, response_handler)

        request.on_complete do |response|
          callback_map[:result] = callback_or_response(response, response_handler)
        rescue StandardError => e
          callback_map[:error] = e
        end

        if callbacks.any_around_callbacks? && ignore_around_callbacks != true
          raise(
            ArgumentError,
            <<~TXT
              `around_fire` callbacks are not supported when firing batches. \
              Pass `ignore_around_callbacks: true` to `execute_in_batch` \
              in order to acknowledge and muffle this.
            TXT
          )
        end

        run_before_fire_callbacks(request, response_handler)

        request
      end

      def finish(request, result, error)
        result = run_after_fire_callbacks(request, request.response, result, error)
        result || (raise error if error)

        result
      end
    end
  end
end
