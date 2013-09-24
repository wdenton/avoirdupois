#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'active_record'
require 'sqlite3'

dbconfig = YAML::load(File.open('config/database.yml'))[ENV['ENV'] ? ENV['ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob('./app/models/*.rb').each { |r| require r }

@layer = Layer.find_by_name("yorkuniversitytoronto")

puts @layer.has_checkboxes

exit

checkmarks = [1, 2]

latitude  = 43.69
longitude = -79.42
radius = 1500

known_checkboxes = Checkbox.find_by_sql(["select c.id from checkboxes c INNER JOIN pois p INNER JOIN checkboxes_pois cp WHERE cp.checkbox_id = c.id AND cp.poi_id = p.id AND p.layer_id = ? GROUP BY c.id", @layer.id]).map {|x| x.id}
puts known_checkboxes

# @layer.pois.group(:id).each do |poi|
#   if poi.within_radius(latitude, longitude, radius)
#     puts "✓ "+ poi.title
#     poi.checkboxes.each do |c|
#       puts c.label
#     end
#   else
#     puts "x " + poi.title
#   end
# end

# exit

# @layer.pois.each do |poi|
#   puts poi.title
# end

# sql = "SELECT *,
#  (((acos(sin((? * pi() / 180)) * sin((lat * pi() / 180)) +  cos((? * pi() / 180)) * cos((lat * pi() / 180)) * cos((? - lon) * pi() / 180))) * 180 / pi())* 60 * 1.1515 * 1.609344 * 1000) AS distance
#  FROM  pois p, checkboxes c, checkboxes_pois cp
#  WHERE p.layer_id = ?
#  AND   cp.checkbox_id = c.id
#  AND   cp.poi_id = p.id
#  AND   c.option_value in (?)
#  GROUP BY p.id HAVING distance < ?
#  ORDER BY distance asc" # "

if known_checkboxes.nil?
  puts "No checkboxes known"
  sql = "SELECT p.*,
 (((acos(sin((? * pi() / 180)) * sin((lat * pi() / 180)) +  cos((? * pi() / 180)) * cos((lat * pi() / 180)) * cos((? - lon) * pi() / 180))) * 180 / pi())* 60 * 1.1515 * 1.609344 * 1000) AS distance
 FROM  pois p
 WHERE p.layer_id = ?
 GROUP BY p.id
 HAVING distance < ?
 ORDER BY distance asc" # "
  pois = Poi.find_by_sql([sql, latitude, latitude, longitude, @layer.id, radius])
else
  # There are some checkboxes known.  But if no checkboxes were passed in, return 0 items
  # by select in (NULL).
  checkmarks = "NULL" if checkmarks.empty?
  puts "Yes, checkboxes known"
  puts "checkmarks = #{checkmarks}"
  sql = "SELECT p.*,
 (((acos(sin((? * pi() / 180)) * sin((lat * pi() / 180)) +  cos((? * pi() / 180)) * cos((lat * pi() / 180)) * cos((? - lon) * pi() / 180))) * 180 / pi())* 60 * 1.1515 * 1.609344 * 1000) AS distance
 FROM  pois p
 INNER JOIN checkboxes_pois cp ON cp.poi_id = p.id
 INNER JOIN checkboxes c ON cp.checkbox_id = c.id
 WHERE p.layer_id = ?
 AND   c.option_value in (?)
 GROUP BY p.id
 HAVING distance < ?
 ORDER BY distance asc" # "
  puts sql
  pois = Poi.find_by_sql([sql, latitude, latitude, longitude, @layer.id, checkmarks, radius])
end

# Unfortunately you can't use nicely named parameters to pass in and make the statement
# more readable, so you have to make sure your ?s match the variables.

pois.each do |poi|
  puts "✓ #{poi.id} #{poi.title}"
end

# pois = l.pois

# puts "All"
# pois.each do |poi|
#   puts poi.title
#   poi.checkboxes.each do |ch|
#     puts "  " + ch.label
#   end
# end

# # puts "Checkbox 1?"
# puts "Checked?"
# checks = []
# # Poi.checkboxed(checks).all

# Poi.checkboxed(checks).each do |poi|
# #  puts poi
#   puts poi.title
# end

