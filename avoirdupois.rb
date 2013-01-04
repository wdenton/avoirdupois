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
require 'sqlite3'

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

radius = params["radius"][0].to_i || 500 # Default to 500m radius if none provided

hotspots = []

@layer.pois.each do |poi|
  # next if poi.distance(latitude, longitude) > radius
  next unless poi.within_radius(latitude, longitude, radius)
  # TODO:
  # Make it so I can do the query thusly:
  # @layer.pois.within_radius(latitude, longtitude, radius).each
  # or something like that
  # See http://guides.rubyonrails.org/active_record_querying.html#scopes
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

  if poi.ubject
    hotspot["object"] = {
      "url"         => poi.ubject.url,
      "reducedURL"  => poi.ubject.reducedURL,
      "contentType" => poi.ubject.contentType,
      "size"        => poi.ubject.size
    }
  end

  # TODO Test a transform
  if poi.transform
    puts poi.transform.url
    hotspot["transform"] = {
      "rotate" => {
        "rel"   => poi.transform.url,
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
  errorstring = "No results found.  (Please customize this error message.)"
  # TODO Customize the error message
end

response = {
  "layer"           => @layer.name,
  "biwStyle"        => @layer.biwStyle,
  "showMessage"     => @layer.showMessage,
  "refreshDistance" => @layer.refreshDistance,
  "refreshInterval" => @layer.refreshInterval,
  "hotspots"        => hotspots,
  "errorCode"       => errorcode,
  "errorString"     => errorstring,
}
# TODO add layer actions

if ! params["radius"]
  response["radius"] = radius
end

puts "Content-type: application/json"
puts
puts response.to_json
