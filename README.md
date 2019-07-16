# NxtHttpClient

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/nxt_http_client`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

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

```
class MyClient < NxtHttpClient
  response_handler do |handler|
    handler.on(:error) do |response|
      raise StandardError, "I can't handle this: #{response.code}"
    end
  end
  
  def call
    fire('www.google.com', method: :get) do |handler|
      handler.on(:success) do |response|
        response.body
      end
      
      handler.on('404') do |response|
        raise StandardError, '404'
      end
    end
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/nxt_http_client.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
