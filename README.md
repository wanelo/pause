# Pause

Pause is a Redis-backed rate-limiting client for Ruby. Use it to track events, with
rules around how often they are allowed to occur within configured time checks.

## Installation

Add this line to your application's Gemfile:

    gem 'pause'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pause

## Usage

Configure Pause. This could be in a Rails initializer.

  * resolution - The time resolution (in seconds) defining the minimum period into which action counts are
                 aggregated. This defines the size of the persistent store. The higher the number, the less data needs
                 to be persisted in Redis.
  * history - The maximum amount of time (in seconds) that data is persisted

```ruby
Pause.configure do |config|
  config.redis_host = "127.0.0.1"
  config.redis_port = 6379
  config.redis_db   = 1

  config.resolution = 600
  config.history    = 86400
end
```

Define local actions for your application. These should define a scope, by
which they are identified in the persistent store, and checks.

Checks are configured with the following arguments:

  * `period_seconds` - this is a period of time against which an action is tested
  * `max_allowed` - the maximum number of times an action can be incremented during the time block determined by
                  period seconds
  * `block_ttl` - how long to mark an action as blocked if it goes over max-allowed

Note that you should not configure a check with `period_seconds` less than the minimum resolution set in the
Pause config. If you do so, you will actually be checking sums against the full time period.

```ruby
require 'pause'

class FollowAction < Pause::Action
  scope "ipn:follow"
  check 600, 100, 300
  check 3600, 200, 1200
end
```

When an event occurs, you increment an instance of your action, optionally with a timestamp and count. This saves
data into a redis store, so it can be checked later by other processes. Timestamps should be in unix epoch format.

```ruby
class FollowsController < ApplicationController
  def create
    action = FollowAction.new(user.id)
    if action.ok?
      # do stuff
      action.increment!
    else
      # show errors
    end
  end
end

class OtherController < ApplicationController
  def index
    action = OtherAction.new(params[:thing])
    if action.ok?
      action.increment!(Time.now.to_i, params[:count].to_i)
    end
  end
end
```

If more data is needed about why the action is blocked, the `analyze` can be called

```ruby
action = MyAction.new("thing")

while true
  action.increment!

  blocked_action = action.analyze

  if blocked_action
    puts blocked_action.identifier
    puts blocked_action.sum
    puts blocked_action.timestamp

    puts blocked_aciton.period_check.inspect
  end

  sleep 1
end
```

## Contributing

Interested in contributing? Awesome. Here's how.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new pull request
