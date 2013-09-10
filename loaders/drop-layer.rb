#!/usr/bin/env ruby

# This file is part of Avoirdupois.
#
# Avoirdupois is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Avoirdupois is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Avoirdupois.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright 2012, 2013 William Denton

# See README.md for how to use this.

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


