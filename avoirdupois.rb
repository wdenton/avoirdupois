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
# Copyright 2012 William Denton

require 'cgi'

require 'rubygems'
require 'active_record'
require 'mysql2'

dbconfig = YAML::load(File.open('config/database.yml'))[ENV['ENV'] ? ENV['ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob('./app/models/*.rb').each { |r| require r }

# URL being called looks like this:
#
# http://www.miskatonic.org/ar/york.php?
# lang=en
# & countryCode=CA
# & userId=6f85d06929d160a7c8a3cc1ab4b54b87db99f74b
# & lon=-79.503089
# & version=6.0
# & radius=1500
# & lat=43.7731464
# & layerName=yorkuniversitytoronto
# & accuracy=100

# Mandatory params passed in:
# userId
# layerName
# version
# lat
# lon
# countryCode
# lang
# action
#
# Optional but important (what if no radius is specified?)
# radius

cgi = CGI.new
params = cgi.params

# Error handling.
# Status 0 indicates success. Change to number in range 20-29 if there's a problem.
errorcode = 0
errorstring = "ok"

@layer = Layer.find_by_name(params["layerName"][0])

# Exit cleanly right away if the requested layer isn't known
if @layer.nil?
  response = {
    "errorCode"   => 20,
    "errorString" => "No such layer " + params["layerName"][0]
  }
  puts response.to_json
  exit
end

latitude  = params["lat"][0].to_f
longitude = params["lon"][0].to_f

radius = params["radius"][0].to_i || 1000 # Default to 1000m radius if none provided

# Turn CHECKBOXLIST=1,2,5 into array of integers [1, 2, 5].
# This gets a bit ugly later.
if params["CHECKBOXLIST"].size > 0
  checkmarks = params["CHECKBOXLIST"][0].split(",").map {|x| x.to_i}
else
  checkmarks = []
end

hotspots = []

# TODO: Add support for nextPageKey
# TODO: Add support for more Pages
# TODO: Add support for layer-level actions
# TODO: Add support for deletedHotspots
# TODO: Add support for animations
# http://layar.com/documentation/browser/api/getpois-response/

# Find all of the POIs in range in this layer.
#
# There's a slightly ugly SQL statement here that's used with a
# find_by_sql statement because we can't use the ActiveRecord methods
# to do exactly what we want: determining the distances between the
# user and the POIs.  We need to use the Haversine formula for this.
# In the SQL statement we do a calculation (thanks to MySQL having all
# of this built in) and then assign that number to the variable
# distance, then select and sort based on distance.  It would be nice
# if we could use ActiveRecord normally to do this, with some sort of
# class method on Poi, but we can't, because there's no way to get
# "as" into the statement.
#
# If we didn't need to bother so much about distance, we could just do
# a query like this:
#
# @layer.pois.group(:id).checkboxed(checkmarks).each do |poi|
#   next unless poi.within_radius(latitude, longitude, radius)
#   puts poi.title
# end
#
# That works fine.  See poi.rb for the checkboxed method, with uses
# ActiveRecord's join and where commands to control the SQL the way we
# want.
#
# If there really is some way to say
# @layer.pois.group(:id).within_range(latitude, longitude, radius)
# then we definitely want to use it.

# Note re tests: make sure the id numbers returned are unique.
# Not specifying IDs from the pois table will lead to trouble.

# All right, this stuff about checkboxes is a bit ugly.
#
# If there are no checkboxes given for a layer, then we don't want to
# use them in our SQL query because it won't work.  So we need to have
# two different SQL queries ready, one for each case.

if @layer.has_checkboxes
  # This layer has some, so we need a more complicated query.

  # When no checkboxes are selected, return nothing with
  # "c.option_value in (NULL) "
  checkmarks = "NULL" if checkmarks.empty?

  # When no checkboxes are selected, assume it's an oversight
  # and return all POIs in range.
  # checkmarks = known_checkboxes if checkmarks.empty?

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
  pois = Poi.find_by_sql([sql, latitude, latitude, longitude, @layer.id, checkmarks, radius])
else
  # We can do a simpler query.
  sql = "SELECT p.*,
 (((acos(sin((? * pi() / 180)) * sin((lat * pi() / 180)) +  cos((? * pi() / 180)) * cos((lat * pi() / 180)) * cos((? - lon) * pi() / 180))) * 180 / pi())* 60 * 1.1515 * 1.609344 * 1000) AS distance
 FROM  pois p
 WHERE p.layer_id = ?
 GROUP BY p.id
 HAVING distance < ?
 ORDER BY distance asc" # "
  pois = Poi.find_by_sql([sql, latitude, latitude, longitude, @layer.id, radius])
end

pois.each do |poi|
  # TODO: Add paging through >50 results.
  # STDERR.puts poi.title
  hotspot = Hash.new
  hotspot["id"] = poi.id
  hotspot["text"] = {
    "title"       => poi.title,
    "description" => poi.description,
    "footnote"    => poi.footnote
  }
  hotspot["anchor"]         = {"geolocation" => {"lat" => poi.lat, "lon" => poi.lon}}
  hotspot["imageURL"]       = poi.imageURL
  hotspot["biwStyle"]       = poi.biwStyle
  hotspot["showSmallBiw"]   = poi.showSmallBiw
  hotspot["showBiwOnClick"] = poi.showBiwOnClick

  if poi.actions
    hotspot["actions"] = []
    poi.actions.each do |action|
      # STDERR.puts action["label"]
      hotspot["actions"] << {
        "uri"          => action.uri,
        "label"        => action.label,
        "contentType"  => action.contentType,
        "activityType" => action.activityType,
        "method"       => action.method
      }
    end
  end

  if poi.icon
    hotspot["icon"] = {
      "url"  => poi.icon.url,
      "type" => poi.icon.iconType
    }
  end

  if poi.ubject # Object being a reserved word in Ruby
    hotspot["object"] = {
      # These three are common to both kinds of objects.
      "url"         => poi.ubject.url,
      "contentType" => poi.ubject.contentType,
      "size"        => poi.ubject.size
    }
    if poi.ubject.contentType == "model/vnd.layar.l3d"
      hotspot["object"]["reducedURL"] = poi.ubject.reducedURL
    elsif poi.ubject.contentType == "text/html"
      hotspot["object"]["viewport"] = {
        "width"       => poi.ubject.width,
        "height"      => poi.ubject.height,
        "scrollable"  => poi.ubject.scrollable,
        "interactive" => poi.ubject.interactive
      }
    end


  end

  # TODO Test a transform
  if poi.transform
    # STDERR.puts poi.transform.url
    hotspot["transform"] = {
      "rotate" => {
        "rel"   => poi.transform.rel,
        "angle" => poi.transform.angle,
        "axis" => {
          "x" => poi.transform.rotate_x,
          "y" => poi.transform.rotate_y,
          "z" => poi.transform.rotate_z,
        }
      },
      "translate" => {
        "x" => poi.transform.translate_x,
        "y" => poi.transform.translate_y,
        "z" => poi.transform.translate_z,
      },
    "scale" => poi.transform.scale
    }
  end

  hotspots << hotspot
end

if hotspots.length == 0
  errorcode = 21
  errorstring = "No results found.  Try adjusting your search range and any filters."
  # TODO Customize the error message
end

response = {
  "layer"           => @layer.name,
  "showMessage"     => @layer.showMessage # + " (#{ENV['ENV']})",
  "refreshDistance" => @layer.refreshDistance,
  "refreshInterval" => @layer.refreshInterval,
  "hotspots"        => hotspots,
  "errorCode"       => errorcode,
  "errorString"     => errorstring,
}
# TODO add layer actions

# "NOTE that this parameter must be returned if the GetPOIs request
# doesn't contain a requested radius. It cannot be used to overrule a
# value of radius if that was provided in the request. the unit is
# meter."
# -- http://layar.com/documentation/browser/api/getpois-response/#root-radius
if ! params["radius"]
  response["radius"] = radius
end

puts "Content-type: application/json"
puts
puts response.to_json
