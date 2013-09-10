#!/usr/bin/env ruby

require 'rubygems'
require 'active_record'
require 'mysql2'

layer = ARGV[0]
if layer.nil?
  puts "Please specify exact layer name"
  exit
end

this_directory = File.dirname(__FILE__)

dbconfig = YAML::load(File.open("#{this_directory}/../config/database.yml"))[ENV['ENV'] ? ENV['ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob("#{this_directory}/../app/models/*.rb").each { |r| require r }

layer_to_drop = Layer.find_by name: layer

if layer_to_drop
  puts "Found #{layer_to_drop.name} ... deleting"
  # With has_and_belongs_to_many and has_many :through, if you want to
  # delete the associated records themselves, you can always do
  # something along the lines of person.tasks.each(&:destroy).
  # l.pois.each(&:destroy)
  if layer_to_drop.destroy
    puts "Success!"
  else
    puts "Failed!"
  end
else
  puts "No such layer"
end


