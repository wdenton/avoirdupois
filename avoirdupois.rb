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

# http://stackoverflow.com/questions/777724/whats-the-best-way-to-talk-to-a-database-while-using-sinatra/786958#786958

# If I moved to DataMapper:
# http://stackoverflow.com/questions/13522912/how-to-add-a-method-in-datamapper-so-i-can-find-all-points-within-x-distance-of
#
# And http://stackoverflow.com/questions/14740195/destroying-dependents-in-datamapper

# my_way
# Sample Sinatra app
# https://github.com/mikker/my_way

require 'rubygems'
require 'bundler/setup'

require 'sinatra'
# require 'nokogiri'
# require 'open-uri'

# require 'data_mapper'

require 'active_record'
require 'mysql2'
require 'yaml'

# Sinatra template app: https://github.com/mikker/my_way

dbconfig = YAML::load(File.open('config/database.yml'))[ENV['RACK_ENV'] ? ENV['RACK_ENV'] : 'development']
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

before do
  # Make this the default
  content_type 'application/json'
end

get "/" do

  # Error handling.
  # Status 0 indicates success. Change to number in range 20-29 if there's a problem.
  errorcode = 0
  errorstring = "ok"

  # See https://www.layar.com/documentation/browser/api/getpois-request/
  # for documentation on the GetPOIs request that is being handled here.

  layer = Layer.find_by name: params[:layerName]

  if layer

    logger.debug "Found layer #{layer.name}"
    logger.debug layer
    logger.debug layer.pois

    latitude  = params[:lat].to_f
    longitude = params[:lon].to_f

    radius = params[:radius].to_i || 1000 # Default to 1000m radius if none provided

    logger.debug "Latitude: #{latitude}"
    logger.debug "Longitude: #{longitude}"
    logger.debug "Radius: #{radius}"

    # Turn CHECKBOXLIST=1,2,5 into array of integers [1, 2, 5].
    # This gets a bit ugly later.
    if params[:CHECKBOXLIST] # .size > 0
      checkmarks = params[:CHECKBOXLIST].split(",").map {|x| x.to_i}
      logger.debug "Checkbox list: #{checkmarks}"
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

    if checkmarks.size > 0  && layer.has_checkboxes
      # This layer has checkboxes configured and checkbox information was passed in.
      # If the layer has checkboxes but no checkbox information is passed, ignore the filters completely
      # and use the simple query (defined in the else).
      logger.debug "Layer has checkboxes; using special query"

      # When no checkboxes are selected, return nothing with
      # "c.option_value in (NULL) "
      checkmarks = "NULL" if checkmarks.empty?

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
      pois = Poi.find_by_sql([sql, latitude, latitude, longitude, layer.id, checkmarks, radius])

    else
      # We can do a simpler query, because either
      # the layer doesn't have any checkboxes defined OR it does but no CHECKBOXLIST was passed in so we'll just ignore it.

      sql = "SELECT p.*,
 (((acos(sin((? * pi() / 180)) * sin((lat * pi() / 180)) +  cos((? * pi() / 180)) * cos((lat * pi() / 180)) * cos((? - lon) * pi() / 180))) * 180 / pi())* 60 * 1.1515 * 1.609344 * 1000) AS distance
 FROM  pois p
 WHERE p.layer_id = ?
 GROUP BY p.id
 HAVING distance < ?
 ORDER BY distance asc" # "
      pois = Poi.find_by_sql([sql, latitude, latitude, longitude, layer.id, radius])
    end

    logger.debug "Found #{pois.size} POIs"

    # pois = layer.pois

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

      logger.debug "Hotspot #{poi.id}: #{poi.title}"

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
      # TODO Make error message customizable?
    end

    response = {
      "layer"           => layer.name,
      "showMessage"     => layer.showMessage, # + " (#{ENV['RACK_ENV']})",
      "refreshDistance" => layer.refreshDistance,
      "refreshInterval" => layer.refreshInterval,
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

  else # The requested layer is not known, so return an error

    errorcode = 22
    errorstring = "No such layer #{params[:layerName]}"
    response = {
      "layer"           => params[:layerName],
      # "refreshDistance" => 300,
      # "refreshInterval" => 100,
      "hotspots"        => [],
      "errorCode"       => errorcode,
      "errorString"     => errorstring,
    }
    logger.error errorstring

   end

  response.to_json

end

get "/*" do
  content_type "text/plain"
  "You need to supply parameters to find POIs for Layar.  See https://github.com/wdenton/avoirdupois"
end
