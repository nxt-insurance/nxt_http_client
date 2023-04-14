module NxtHttpClient
  def self.execute_in_batch(*client_instances, ignore_around_callbacks: false, raise_errors: true)
    client_map = Hash.new do |hash, key|
      hash[key] = { request: nil, error: nil, result: nil }
    end

    client_instances.each do |client|
      client.singleton_class.include(NxtHttpClient::Client::BatchPatch)
      client.assign_batch_data(client_map[client], ignore_around_callbacks)
    end

    hydra = Typhoeus::Hydra.new

    client_instances.each do |client|
      client.call.tap do |request|
        hydra.queue(request)
      end
    end

    hydra.run

    client_map.map do |client, response_data|
      client.finish(response_data[:request], response_data[:result], response_data[:error], raise_errors: raise_errors)
    end
  end
end
