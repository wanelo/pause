# Pause

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'pause'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pause

## Usage

Define local actions for your application

```ruby
require 'pause'

class FollowAction < Pause::Action
  scope "ipn:follow"
  check 100, 100, 200
  check 200, 150, 250
end
```



Configure Pause. This could be in a Rails initializer.

```ruby
Pause.configure do |config|
  config.redis_host = "127.0.0.1"
  config.redis_port = 6379
  config.resolution = 10
  config.history    = 60
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
