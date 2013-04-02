#!/usr/bin/env ruby

require 'yaml'

require 'rubygems'
require 'active_record'

layer = ARGV[0]
if layer.nil?
  puts "Please specify a layer to remove"
  exit
end

dbconfig = YAML::load(File.open('config/database.yml'))[ENV['ENV'] ? ENV['ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob('./app/models/*.rb').each { |r| require r }

l = Layer.find_or_create_by_name(:name => layer,
                            :refreshInterval => 300,
                            :refreshDistance => 100,
                            :fullRefresh => true,
                            :showMessage => "",
                            :biwStyle => "classic",
                            )

puts "Found #{l.name} ... deleting"

# With has_and_belongs_to_many and has_many :through, if you want to delete the associated records themselves, you can always do something along the lines of person.tasks.each(&:destroy).

# l.pois.each(&:destroy)
l.destroy
