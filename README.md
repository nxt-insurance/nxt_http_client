# NxtHttpClient

Build http clients with ease. NxtHttpClient is a simple DSL on top of the [typhoeus](https://github.com/typhoeus/typhoeus)
gem. NxtHttpClient mostly provides you a simple configuration functionality to setup http connections on the class level.
Furthermore it's mostly a callback framework that allows you to seamlessly handle your responses. Since it's is just a simple
layer on top of [typhoeus](https://github.com/typhoeus/typhoeus) it also allows to access and configure the original
`Typhoeus::Request` before making a request.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nxt_http_client'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nxt_http_client

## Usage

A typical client could look something like this:

```ruby
class UserFetcher < Client
  def initialize(id)
    @url = ".../users/#{id}"
  end

  def call
    get(url) do |response_handler|
      response_handler.on(:success) do |response|
        JSON(response.body)
      end
    end
  end

  private

  attr_reader :url
end
```

In order to setup a shared configuration you would therefore setup a client base class. The configuration and any
response handler or callbacks you setup in your base class are then inherited to your concrete client implementations.

```ruby
class Client < NxtHttpClient
  configure do |config|
    config.base_url = 'www.example.com'
    config.request_options.deep_merge!(
      headers: { API_KEY: '1993' },
      method: :get,
      followlocation: true
    )
    config.x_request_id_proc = -> { ('a'..'z').to_a.shuffle.take(10).join }
  end

  log do |info|
    Rails.logger.info(info)
  end

  response_handler do |handler|
    handler.on(:error) do |response|
      Raven.extra_context(error_details: error.to_h)
      raise StandardError, "I can't handle this: #{response.code}"
    end
  end
end
```

### HTTP Methods

In order to build a request and execute it NxtHttpClient implements all http standard methods.

```ruby
class Client < NxtHttpClient
  def initialize(url)
    @url = url
  end

  attr_reader :url

  def fetch
    get(url) do
      handler.on(:success) { |response| response.body }
    end
  end

  def create(params)
    post(url, params: params) do
      handler.on(:success) { |response| response.body }
    end
  end

  def update(params)
    put(url, params: params) do
      handler.on(:success) { |response| response.body }
    end
  end

  # ... there are others as you know ...
end
```

### configure

Register your default request options on the class level. Available options are `request_options` that are passed
directly to the underlying Typhoeus Request. Then there is `base_url` and `x_request_id_proc`.

### response_handler

Register a default response handler for your client class. You can reconfigure or overwrite this in subclasses and
on the instance level.

### fire

All http methods internally are delegate to `fire('uri', **request_options)`. Since `fire` is a public method you can
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
NxtHttpClient::Error exposes the `timed_out?` method from `Typhoeus::Response`, so you can check if an error is raised due to a timeout. This is useful when setting a custom timeout value in your configuration.

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
