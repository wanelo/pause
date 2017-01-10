require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => [ 'spec:unit', 'spec:integration' ]

namespace :spec do
  desc 'Run specs using fakeredis'
  task :unit do
    ENV['PAUSE_REAL_REDIS'] = nil
    Rake::Task["spec"].execute
  end
  desc 'Run specs against a local Redis server'
  task :integration do
    ENV['PAUSE_REAL_REDIS'] = 'true'
    Rake::Task["spec"].execute
  end
end
