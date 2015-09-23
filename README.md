Pause
======

[![Gem Version](https://badge.fury.io/rb/pause.png)](http://badge.fury.io/rb/pause)
[![Build status](https://secure.travis-ci.org/wanelo/pause.png)](http://travis-ci.org/wanelo/pause)

Pause is a flexible Redis-backed rate-limiting client. Use it to track events, with
rules around how often they are allowed to occur within configured time checks.

Because Pause is Redis-based, multiple ruby processes (even distributed across multiple servers) can track and report
events together, and then query whether a particular identifier should be rate limited or not.

Sample applications include IP-based blocking based on HTTP request volume (see related gem "spanx"),
throttling push notifications as to not overwhelm the user with too much frequency, etc.

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
  scope "f"
  check period_seconds:   60, max_allowed:  100, block_ttl: 3600
  check period_seconds: 1800, max_allowed: 2000, block_ttl: 3600
end
```

When an event occurs, you increment an instance of your action, optionally with a timestamp and count. This saves
data into a redis store, so it can be checked later by other processes. Timestamps should be in unix epoch format.

```ruby
class FollowsController < ApplicationController
  def create
    action = FollowAction.new(user.id)
    if action.ok?
      # do stuff!
      # and track it...
      action.increment!
    else
      # action is rate limited, either skip
      # or show error, depending on the context.
    end
  end
end

class OtherController < ApplicationController
  def index
    action = OtherAction.new(params[:thing])
    unless action.rate_limited?
      # perform business logic
      ....
      # track it
      action.increment!(params[:count].to_i, Time.now.to_i)
    end
  end
end
```

If more data is needed about why the action is blocked, the `analyze` can be called

```ruby
action = NotifyViaEmailAction.new("thing")

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

## Contributing

Want to make it better? Cool. Here's how:

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new pull request

## Authors

This gem was written by Eric Saxby, Atasay Gokkaya and Konstantin Gredeskoul at Wanelo, Inc.

Please see the LICENSE.txt file for further details.


