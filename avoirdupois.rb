#!/usr/bin/env ruby

require 'rubygems'
require 'active_record'

require 'sqlite3'
require 'yaml'

dbconfig = YAML::load(File.open('config/database.yml'))[ENV['ENV'] ? ENV['ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob('./app/models/*.rb').each { |r| require r }

l = Layer.find_by_layer("Hello")

puts "Content-type: text/plain"
puts
puts "Trying"

puts l.layer

pois = l.pois.find(:all)

pois.each do |poi|
  puts poi.title
end
