require 'bundler'
require 'rvm/capistrano'
require 'bundler/capistrano'

require 'ostruct'
config_file = File.join File.dirname(__FILE__), 'config.yml'
raw_config = YAML::load File.open(config_file, 'r').read
config = OpenStruct.new raw_config

set :application, config.application
set :domain, config.domain

set :use_sudo, false
set :deploy_to, config.deploy_path
set :user, config.deploy_user

set :unicorn_bin, 'unicorn' unless exists?(:unicorn_bin)
set :unicorn_pid, File.join(shared_path, "pids", "unicorn.pid")
set :sockets_path, File.join(shared_path, "sockets")
set :current_sockets_path, File.join(current_path, "tmp", "sockets")

set :scm, :git
set :branch, config.repository_branch
set :repository, config.repository
set :deploy_via, :remote_cache

set :rvm_gemset, config.rvm_gemset
set :rvm_ruby_string, config.rvm_ruby_string

server domain, :app, :web, :db, :primary => true

def unicorn_start_cmd
  "bundle exec #{unicorn_bin} -c config/unicorn.rb -D"
end

namespace :deploy do

  desc "Create the database (only necessary the first time)."
  task :db, :roles => :app do
    run "cd #{current_path} && rake db"
  end

  desc "Create the RVM gemset."
  task :create_gemset, :roles => :app do
    run "#{try_sudo} rvm gemset create #{rvm_gemset}"
  end

  desc <<-DESC
    Starts the application server. This will run unicorn as a deamon, \
    using the configuration found in config/unicorn.rb.
  DESC
  task :start, :roles => :app do
    run "cd #{current_path} && #{unicorn_start_cmd}"
  end

  desc <<-DESC
    Stops the application server. This will send a QUIT signal to the \
    unicorn process with the id found in tmp/pids/unicorn.pid.
  DESC
  task :stop, :roles => :app do
    run "kill -QUIT `cat #{unicorn_pid}`"
  end

  desc <<-DESC
    Restarts the application server. If unicorn is already running, this \
    will send a TERM signal to the unicorn process with the id found in \
    tmp/pids/unicorn.pid. It will then do the same as deploy:start.
  DESC
  task :restart, :roles => :app do
    run "cd #{current_path}; [ -f #{unicorn_pid} ] && kill -TERM `cat #{unicorn_pid}` ; #{unicorn_start_cmd}"
  end

  desc <<-DESC
    [internal] Creates a shared sockets directory in shared/sockets. \
    This is meant to be called after deploy:setup.
  DESC
  task :setup_sockets, :roles => :app , :except => { :no_release => true } do
    run "#{try_sudo} mkdir -p #{sockets_path}"
    run "#{try_sudo} chown #{user} #{sockets_path} -R"
  end

  desc <<-DESC
    [internal] Creates a symlink from tmp/sockets to the shared sockets \
    directory in shared/sockets. This is meant to be called after deploy:update.
  DESC
  task :symlink_sockets, :roles => :app do
    run "#{try_sudo} ln -s #{sockets_path} #{current_sockets_path}"
  end
end

before 'deploy', 'deploy:create_gemset'
after 'deploy:setup', 'deploy:setup_sockets'
after 'deploy:update', 'deploy:symlink_sockets'
