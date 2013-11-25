require 'rubygems'
require 'sinatra'
require 'active_record'
require 'rack/logger'

configure :development do
  set :logging, Logger::DEBUG
end

set :environment, ENV['RACK_ENV'].to_sym
disable :run, :reload

require './avoirdupois.rb'
run Sinatra::Application
