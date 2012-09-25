
require 'ostruct'
config_file = File.join File.dirname(__FILE__), 'config.yml'
raw_config = YAML::load File.open(config_file, 'r').read
config = OpenStruct.new raw_config

root = "#{config.deploy_path}/current"

# Unicorn
God.watch do |w|
  w.dir = root
  w.name = "integrity-unicorn"
  w.group = "integrity"
  w.start = "bundle exec unicorn -c config/unicorn.rb -D"
  w.pid_file = "#{root}/tmp/pids/unicorn.pid"
  w.interval = 30.seconds
  w.keepalive
end

# Resque
num_workers = config.workers || 1
num_workers.times do |num|

  pid_file = "#{root}/tmp/pids/resque.#{num}.pid"

  God.watch do |w|
    w.dir = root
    w.name = "integrity-resque-#{num}"
    w.group = "integrity"
    w.env = { "QUEUE" => "integrity", "BACKGROUND" => "yes", "PIDFILE" => pid_file }
    w.start = "bundle exec rake resque:work"
    w.pid_file = pid_file
    w.interval = 30.seconds
    w.keepalive
  end
end
