# Pause

[![Gem Version](https://badge.fury.io/rb/pause.png)](http://badge.fury.io/rb/pause)
[![Build Status](https://travis-ci.org/kigster/pause.svg?branch=master)](https://travis-ci.org/kigster/pause)

## In a Nutshell

**Pause** is a fast and very flexible Redis-backed rate-limiter. You can use it to track events, with
rules around how often they are allowed to occur within configured time checks.

Sample applications include:
 
 * throttling notifications sent to a user as to not overwhelm them with too much frequency,
 * IP-based blocking based on HTTP request volume (see the related gem [spanx](https://github.com/wanelo/spanx)) that uses Pause,
 * ensuring you do not exceed API rate limits when calling external web APIs.
 * etc.
 
Pause currently does not offer a CLI client, and can only be used from within a Ruby application.

Additionally:

 * Pause is pure-ruby gem and does not depend on Rails or Rack
 * Pause can be used across multiple ruby processes, since it uses a distributed Redis backend
 * Pause is currently in use by a web application receiving 6K-10K web requests per second
 * Pause will work with a horizontally sharded multi-Redis-backend by using Twitter's [Twemproxy](https://github.com/twitter/twemproxy). This way, millions of concurrent users can be handled with ease.

### Quick Start

This section is meant to give you a rapid introduction, so that you can start using Pause immediately.

Our use case: we want to rate limit notifications sent to users, identified by their `user_id`, to:

 * no more than 1 in any 2-hour period
 * no more than 3 per day
 * no more than 7 per week

Here is how we could set this up using Pause:

#### Configuration

We need to setup Pause with a Redis instance. Here is how we do it:

```ruby
require 'pause'

# First, lets point Pause to a Redis instance
Pause.configure do |config|
  # Redis connection parameters
  config.redis_host = '127.0.0.1'
  config.redis_port = 6379
  config.redis_db   = 1
  
  config.resolution = 600     
  config.history    = 7 * 86400  # discard events older than 7 days   
end
```

> NOTE: **resolution** is an setting that's key to understanding how Pause works. It represents the length of time during which similar events are aggregated into a Hash-like object, where the key is the identifier, and the value is the count within that period.
> 
> Because of this,
>  
>   * _Larger resolution requires less RAM and CPU and are faster to compute_
>   * _Smaller resolution is more computationally expensive, but provides higher granularity_.
>
> The resolution setting must set to the smallest rate-limit period across all of your checks. Below it is set to 10 minutes, meaning that you can use Pause to **rate limit any event to no more than N times within a period of 10 minutes or more.**


#### Define Rate Limited "Action"

Next we must define the rate limited action based on the specification above. This is how easy it is:

```ruby
module MyApp
  class UserNotificationLimiter < ::Pause::Action
    # this is a redis key namespace added to all data in this action
    scope 'un'  
    
    check period_seconds:      120, 
          max_allowed:           1, 
          block_ttl:           240
          
    check period_seconds:    86400, 
          max_allowed:           3
          
    check period_seconds: 7 *86400, 
          max_allowed:           7
  end
end
```

> NOTE: for each check, `block_ttl` defaults to `period_seconds`, and represents the duration of time the action will consider itself as "rate limited" after a particular check reaches the limit.  Note, that all actions will automatically leave the "rate limited" state after `block_ttl` seconds have passed.

#### Perform operation, but only if the user is not rate-limited

Now we simply instantiate this limiter by passing user ID (any unique identifier works). We can then ask the limiter, `ok?` or `rate_limited?`, or we can use two convenient methods that only execute enclosed block if the described condition is satisfied:

```ruby
class NotificationsWorker
  def perform(user_id)
    MyApp::UserNotificationLimiter.new(user_id) do 
      unless_rate_limited do
        # this block ONLY runs if rate limit is not reached
        user = User.find(user_id) 
        user.send_push_notification!
      end
      
      if_rate_limited do |rate_limit_event|
        # this block ONLY runs if the action has reached it's rate limit.
        Rails.logger.info("user #{user.id} has exceeded rate limit: #{rate_limit_event}") 
      end
    end   
  end
end
```

That's it! Using these two methods you can pretty much ensure that your rate limits are always in check. 


## Installation

Add this line to your application's Gemfile:

    gem 'pause'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pause

## Usage

### Configuration

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
  config.resolution = 600     # aggregate all events into 10 minute blocks
  config.history    = 86400   # discard all events older than 1 day
end
```

### Actions

Define local actions for your application. Actions define a scope by
which they are identified in the persistent store (aka "namespace"), and a set of checks.  Checks define various
thresholds (`max_allowed`) against periods of time (`period_seconds`). When a threshold it triggered,
the action is rate limited, and stays rate limited for the duration of `block_ttl` seconds.

#### Checks

Checks are configured with the following arguments (which can be passed as an array, or a symbol hash):

  * `period_seconds` - time window this is a time period against which an action is tested
  * `max_allowed` - the maximum number of times an action can be incremented during this particular time period before rate limiting is triggered.
  * `block_ttl` - amount time (seconds) an action stays rate limited after threshold is reached.

#### Scope

Scope is simple string used to identify this action in the Redis store, and is appended to all keys.
Therefore it is advised to keep scope as short as possible to reduce memory requirements of the store.

If you are using the same Redis store to rate limit multiple actions, you must ensure that each action
has a unique scope.

#### Resolution

Resolution is the period of aggregation.  As events come in, Pause aggregates them in time blocks
of this length.  If you set resolution to 10 minutes, all events arriving within a 10 minute block
are aggregated.

Resolution must be less than or equal to the smallest `period_seconds` value in your checks.
In other words, if your shortest check is 1 minute, you could set resolution to 1 minute or smaller.

#### Example

```ruby
require 'pause'

class FollowAction < Pause::Action
  scope 'fa' # keep those short
  check period_seconds:   60, max_allowed:  100, block_ttl: 3600
  check period_seconds: 1800, max_allowed: 2000, block_ttl: 3600
end
```

When an event occurs, you increment an instance of your action, optionally with a timestamp and count. This saves data into a redis store, so it can be checked later by other processes. Timestamps should be in unix epoch format.

In the example at the top of the README you saw how we used `#unless_rate_limited` and `#if_rate_limited` methods. These are the recommended API methods, but if you must get a finer-grained control over the actions, you can also use methods such as `#ok?`, `#rate_limited?`, `#increment!` to do manually what the block methods do already. Below is an example of this "manual" implementation:

```ruby
class FollowsController < ApplicationController
  def create
    action = FollowAction.new(user.id)
    if action.ok?
      user.follow! 
      # and don't forget to track the "success"
      action.increment!
    end
  end
end

class OtherController < ApplicationController
  def index
    action = OtherAction.new(params[:thing])d
    unless action.rate_limited?
      # perform business logic
      # but in this
      action.increment!(params[:count].to_i, Time.now.to_i)
    end
  end
end
```

If more data is needed about why the action is blocked, the `analyze` can be called:

```ruby
action = NotifyViaEmailAction.new(:thing)

while true
  action.increment!

  rate_limit_event = action.analyze
  if rate_limit_event
    puts rate_limit_event.identifier               # which key got rate limited ("thing")
    puts rate_limit_event.sum                      # total count that triggered a rate limit
    puts rate_limit_event.timestamp                # timestamp when rate limiting occurred
    puts rate_limit_event.period_check             # period check object, that triggered this rate limiting event
  else
    # not rate-limited, same as action.ok?
  end

  sleep 1
end
```

## Enabling/Disabling Actions

Actions have a built-in way by which they can be disabled or enabled.

```ruby
MyAction.disable
MyAction.enable
```

This is persisted to Redis, so state is not process-bound, but shared across all ruby run-times using this
action (assuming Redis store configuration is the same).

When disabled, Pause does *not* check state in any of its methods, so calls to increment! or ok? still work
exactly as before. This is because adding extra Redis calls can be expensive in loops. You should check
whether your action is enabled or disabled if it important to support enabling and disabling of rate limiting in
your context.

```ruby
while true
  if MyAction.enabled?
    Thing.all.each do |thing|
      action = MyAction.new(thing.name)
      action.increment! unless action.rate_limited?
    end
  end
  sleep 10
end
```

## Unblocking

Actions can be unblocked manually after they have been blocked.

To unblock all blocked identifiers for a single action:

```ruby
MyAction.unblock_all
```

To unblock a single identifier for an action:

```ruby
action = MyAction.new('hello')

action.ok?
# => false

action.unblock

action.ok?
# => true
```

## Using Pause with Twemproxy

Pause can be used with Twemproxy to shard its data among multiple redis instances. When doing so,
the `hash_tag` configuration in Twemproxy should be set to `"||"`. In addition, the `sharded` Pause
configuration option should be set to true.

When sharding is used, the Redis adapter used by Pause ignores the `redis_db`, which is not supported.

```ruby
Pause.configure do |config|
  config.redis_host = "127.0.0.1"
  config.redis_port = 6379
  config.resolution = 600     # aggregate all events into 10 minute blocks
  config.history    = 86400   # discard all events older than 1 day
  config.sharded    = true
end
```

With this configuration, any Pause operation that we know is not supported by Twemproxy will raise
`Pause::Redis::OperationNotSupported`. For instance, when sharding we are unable to get a list of all
tracked identifiers.

The action block list is implemented as a sorted set, so it should still be usable when sharding.

## Testing

By default, `fakeredis` gem is used to emulate Redis in development. However, the same test-suite should be able to run against a real redis — however, be aware that it will flush the current db during spec run. In order to run specs against real redis, make sure you have Redis running locally on the default port, and that you are able to connect to it using `redis-cli`.

Please note that Travis suite, as well as the default rake task, run both.

### Unit Testing with Fakeredis

Fakeredis is the default, and is also run whenever `bundle exec rspec` is executed, or `rake spec` task invoked.

```bash
bundle exec rake spec:unit
```

### Integration Testing with Redis

```bash
bundle exec rake spec:integration
```

## Contributing

Want to make it better? Cool. Here's how:

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new pull request

## Authors

 * This gem was written by Eric Saxby, Atasay Gokkaya and Konstantin Gredeskoul at Wanelo, Inc.
 * It's been updated and refreshed by Konstantin Gredeskoul.


Please see the [LICENSE.txt](LICENSE.txt) file for further details.


