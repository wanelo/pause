require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yard'

RSpec::Core::RakeTask.new(:spec)

task :default => %w(spec:unit spec:integration)

namespace :spec do
  desc 'Run specs using fakeredis'
  task :unit do
    ENV['PAUSE_REAL_REDIS'] = nil
    Rake::Task['spec'].execute
  end
  desc 'Run specs against a local Redis server'
  task :integration do
    ENV['PAUSE_REAL_REDIS'] = 'true'
    Rake::Task['spec'].execute
  end
end

def shell(*args)
  puts "running: #{args.join(' ')}"
  system(args.join(' '))
end

task :clean do
  shell('rm -rf pkg/ tmp/ coverage/ doc/ ' )
end

task :gem => [:build] do
  shell('gem install pkg/*')
end

task :permissions => [ :clean ] do
  shell('chmod -v o+r,g+r * */* */*/* */*/*/* */*/*/*/* */*/*/*/*/*')
  shell("find . -type d -exec chmod o+x,g+x {} \\;")
end

task :build => :permissions

YARD::Rake::YardocTask.new(:doc) do |t|
  t.files = %w(lib/**/*.rb exe/*.rb - README.md LICENSE.txt)
  t.options.unshift('--title','"Pause - Redis-backed Rate Limiter"')
  t.after = ->() { exec('open doc/index.html') }
end

