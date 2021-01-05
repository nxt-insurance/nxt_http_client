# NxtHttpClient

Build http clients with ease. NxtHttpClient is a simple DSL on top of the awesome [typhoeus](https://github.com/typhoeus/typhoeus)
gem. Configure your http clients on the class level and then adjust them on a request options on the instance level if necessary.
All http interactions are handled by [typhoeus](https://github.com/typhoeus/typhoeus). If you need to access the original `Typhoeus::Request` in your instance, you can do that. 


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

```ruby
class ApplicationFetcher < Client
  def initialize(id)
    @url = ".../applications/#{id}"
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


```ruby
class MyClient < NxtHttpClient
  
  # In your subclasses you probably want to deep_merge options in order to not overwrite options inherited 
  # from the parent class. Of course this will not influence the parent class and you can also reset them 
  # to a new hash here.
  
  # Also be aware that the result of x_request_id_proc will be hashed into the cache key and thus might cause 
  # your request not to be cached if not used properly

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
      Raven.extra_context(error_details: error.to_h) # call error.to_h to inspect request and response
      raise StandardError, "I can't handle this: #{response.code}"
    end
  end
  
  # Will be called before fire so you can reconfigure your handler before fire
  before_fire do |client, request, handler|
    handler.on!(200) do |response|
      # ...
    end
  end
  
  # Will be called after fire. You probably want to return the result here in order for your code 
  # to be able to access the result from the response handler from before. 
  # In case one of the response handler callbacks raises an error
  # after fire will has access to it and you may want to reraise the error in that case.

  after_fire do |client, request, response, result, error|
    if error
      raise error
    else  
      result
    end
  end
  
  def fetch_details
    fire('details', method: :get) do |handler|
      handler.on(:success) do |response|
        response.body
      end
      
      handler.on(404) do |response|
        raise StandardError, '404'
      end
      
      # You can also fuzzy match response codes using the wildcard *
      handler.on('5**') do |response|
        raise StandardError, 'This is bad'
      end
    end
  end
  
  # there are also convenience methods for all http verbs (get post patch put delete head)
  def update
    post(params: { my: 'payload' }) do |handler|
    # ...
    end
  end
end
```

### HTTP Methods

Instead of fire you can simply use the http verbs as methods

```ruby
class MyClient < NxtHttpClient
  
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

Register default request options on the class level. Available options are `request_options` that are passed directly to 
the underlying Typhoeus Request. Then there is `base_url` and `x_request_id_proc`. 

### response_handler

Register a default response handler for your client class. 
You can reconfigure or overwrite it this completely later on the instance level. 

### fire

Use `fire('uri', **request_options)` to actually fire your requests and define what to do with the response by using
the NxtHttpClient DSL. Registered callbacks have a hierarchy by which they are executed. Specific callbacks will come first 
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

You can also hook into the before_fire and after_fire callbacks to do something before and after the actual request is executed.
These callbacks are inherited down the class hierarchy but are not being chained. Meaning when you overwrite those in your subclass,
the callbacks defined by your parent class will not be called anymore.

### NxtHttpClient::Error

NxtHttpClient also provides an error base class that you might want to use as the base for your client errors.
It comes with a nice set of useful methods. You can ask the error for the request and response options since it
requires the response for initialization. 

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/nxt_http_client.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
