# NxtHttpClient

Build http clients with ease. NxtHttpClient is a DSL on top of the [typhoeus](https://github.com/typhoeus/typhoeus)
gem. NxtHttpClient provides configuration functionality to set up HTTP connections on the class level, and attach
callbacks that allow you to seamlessly handle responses, as well as configure the original
`Typhoeus::Request` before making a request.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nxt_http_client'
```

And then execute:

```sh
bundle
````

## Usage

Here's a simple HTTP client with this gem:

```ruby
client = NxtHttpClient::Client.make do 
  configure do |config|
    config.base_url = 'www.httpstat.us'
    config.request_options.deep_merge!(
      headers: { API_KEY: '1993' },
      followlocation: true
    )
    config.json_request = true
    config.json_response = true
  end
end

client.get('200')
client.post('200', body: { some: 'content'})
```

This is good when you need a one-off client to make some quick API calls. 
However, you can go further by creating custom client classes with shared configuration,
and customizing them as needed.
For example, you could have a base client for interacting with a specific service:

```ruby
class UserServiceClient < NxtHttpClient::Client
  # Set a base URL, and any other request options you need
  configure do |config|
    config.base_url = 'www.example.com'
    config.json_request = true
    config.json_response = true
    config.bearer_auth = ENV['USER_SERVICE_API_TOKEN']
    config.x_request_id_proc = -> { ('a'..'z').to_a.shuffle.take(10).join }
  end

  # You may add a log handler if you wish...
  log do |info|
    Rails.logger.info(info)
  end

  # ...as well as a response handler
  response_handler do |handler|
    handler.on(:error) do |response|
      Sentry.set_extras(error_details: error.to_h)
      raise StandardError, "I can't handle this: #{response.code}"
    end
  end
end
```

and then child classes for accessing specific endpoints and adding custom behaviours.

```ruby
class UserFetcher < UserServiceClient
  def initialize(id)
    @url = ".../users/#{id}"
  end

  def fetch_email
    get(url, { fields: :email }) do |response_handler|
      response_handler.on(:success) do |response|
        JSON(response.body)['email']
      end
    end
  end

  def fetch_user_details
    get(url) do |response_handler|
      response_handler.on(:success) do |response|
        body = JSON(response.body)
        User.new(body)
      end
    end
  end

  private attr_reader :url
end
```

Usage:

```ruby
client = UserFetcher.new('1234')
client.fetch_email
client.fetch_user_details
```

### configure

Register your default request options on the class level. Available options are:
- `request_options`, passed directly to the underlying Typhoeus Request
- `base_url=`
- `x_request_id_proc=`
- `json_request=`: Shorthand to set the Content-Type request header to JSON and automatically convert request bodies to JSON
- `json_response=`: Shorthand to set the Accept request header and automatically convert success response bodies to JSON
- `raise_response_errors=`: Makes the client raise a `NxtHttpClient::Error` for a non-success response. 
  You can also do this manually by setting a response_handler.
- `bearer_auth=`: Set a bearer token to be sent in the Authorization header
- `basic_auth=`: Pass an array containing username and password, to be sent as Basic credentials in the Authorization header
- `timeouts(total:, connect: nil)`: Configure timeouts

### response_handler

Register a default response handler for your client class. You can reconfigure or overwrite this in subclasses and
on the instance level.

### fire

All http methods internally are delegate to `fire(uri, **request_options)`. Since `fire` is a public method you can
also use it to fire your requests and use the response handler to register callbacks for specific responses.

Registered callbacks have a hierarchy by which they are executed. Specific callbacks will come first
and more common callbacks will come later in case none of the specific callbacks matched. It this is not what you want you
can simply put the logic you need into one common callback that is called in any case. You can also use strings with wildcards
to match a group of response by status code. `handler.on('4**') { ... }` basically would match all client errors.   

```ruby
fire('uri', **request_options) do |handler|
  handler.on(:any) do |response|
    raise StandardError, 'This would overwrite all others since it matches first'
  end

  handler.on(:success) do |response|
    response.body
  end

  handler.on(:timed_out) do |response|
    raise StandardError, 'Timeout'
  end

  handler.on(:error) do |response|
    raise StandardError, 'This is bad'
  end

  handler.on(:others) do |response|
    raise StandardError, 'Other problem'
  end

  handler.on(:headers) do |response|
    # This is already executed when the headers are received
  end

  handler.on(:body) do |chunk|
   # Use this to stream the body in chunks
  end
end
```

### Callbacks around fire

Next to implementing callbacks for handling responses there are also callbacks around making requests. Note tht you can
have as many callbacks as you want. In case you need to reset them because you do not want to inherit them from your
parent class (might be a smell when you need to...) you can reset callbacks via `clear_fire_callbacks` on the class level.

```ruby

clear_fire_callbacks # Call this to clear callbacks setup in the parent class

before_fire do |client, request, response_handler|
  # here you have access to the client, request and response_handler  
end

around_fire do |client, request, response_handler, fire|
  # here you have access to the client, request and response_handler
  fire.call # You have to call fire here and return the result to the next callback in the chain
end

after_fire do |client, request, response, result, error|
  result # The result of the last callback in the chain is the result of fire!
end
```


### NxtHttpClient::Error

NxtHttpClient also provides an error base class that you might want to use as the base for your client errors.
It comes with a nice set of useful methods. You can ask the error for the request and response options since it
requires the response for initialization. Furthermore it has a handy `to_h` method that provides you all info about
the request and response.

#### Timeouts
NxtHttpClient::Error exposes the `timed_out?` method from `Typhoeus::Response`, so you can check if an error is raised due to a timeout. 
This is useful when setting a custom timeout value in your configuration.

### Logging

NxtHttpClient also comes with a log method on the class level that you can pass a proc if you want to log your request.
Your proc needs to accept an argument in order to get access to information about the request and response made.  

```ruby
log do |info|
  Rails.logger.info(info)
end

# info is a hash that is implemented as follows:

{
  client: client,
  started_at: started_at,
  request: request,
  finished_at: now,
  elapsed_time_in_milliseconds: finished_at - started_at,
  response: request.response,
  http_status: request.response&.code
}
```

### Caching

Typhoeus ships with caching built in. Checkout the [typhoeus](https://github.com/typhoeus/typhoeus) docu to figure out
how to set it up. NxtHttpClient builds some functionality on top of this and offer to cache requests within the current
thread or globally. You can simply make use of it by providing one of the caching options `:thread` or`:global` as config
request option or the actual request options when building the request.

```ruby
class Client < NxtHttpClient::Client
  configure do |config|
    config.request_options = { cache: :thread }
  end

  response_handler do |handler|
    handler.on(200) do |response|
      # ...
    end
  end

  def call
    get('.../url.com', cache: :thread) # configure caching per request level
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nxt-insurance/nxt_http_client.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
