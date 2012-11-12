require 'spec_helper'

describe Pause::Configuration, "#configure" do

  subject { Pause::Configuration.new }

  it "should allow configuration via block" do
    subject.configure do |c|
      c.redis_host = "128.23.12.8"
      c.redis_port = "2134"
      c.redis_db = "13"

      c.resolution = 5000
      c.history = 6000
    end

    subject.redis_host.should == "128.23.12.8"
    subject.redis_port.should == 2134
    subject.redis_db.should == "13"

    subject.resolution.should == 5000
    subject.history.should == 6000
  end

  it "should provide redis defaults" do
    subject.configure do |config|
      # do nothing
    end

    subject.redis_host.should == "127.0.0.1"
    subject.redis_port.should == 6379
    subject.redis_db.should == "1"
    subject.resolution.should == 600 # 10 minutes
    subject.history.should == 86400 # one day
  end
end
