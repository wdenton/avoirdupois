#!/usr/bin/env ruby

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
    "errorCode" => 20,
    "errorString" => "No such layer " + params["layerName"][0]
  }
  puts response.to_json
  exit
end

latitude = params["lat"][0].to_f
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
    "title" => poi.title,
    "description" => poi.description,
    "footnote" => poi.footnote
  }
  hotspot["anchor"] = {"geolocation" => {"lat" => poi.lat, "lon" => poi.lon}}
  hotspot["imageURL"] = poi.imageURL
  hotspot["biwStyle"] = poi.biwStyle
  hotspot["showSmallBiw"] = poi.showSmallBiw
  hotspot["showBiwOnClick"] = poi.showBiwOnClick

  # Associate any actions
  if defined?(poi.actions)
    # puts poi["title"]
    hotspot["actions"] = []
    poi.actions.each do |action|
      # puts action["uri"]
      # puts action["label"]
      hotspot["actions"] << {
        "uri" => action.uri,
        "label" => action.label,
        "contentType" => action.contentType,
        "activityType" => action.activityType,
        "method" => action.method
      }
    end
  end

  # Is there an icon?
  if defined?(poi.icon)
    hotspot["icon"] = {
      "url" => poi.icon.url,
      "type" => poi.icon.iconType
    }
  end

  hotspots << hotspot
end

if hotspots.length == 0
  errorcode = 21
  errorstring = "No results found.  Are you on a York campus or near a York building?"
end

response = {
  "layer" => @layer.name,
  "biwStyle" => @layer.biwStyle,
  "showMessage" => @layer.showMessage,
  "refreshDistance" => @layer.refreshDistance,
  "refreshInterval" => @layer.refreshInterval,
  "hotspots" => hotspots,
  "errorCode" => errorcode,
  "errorString" => errorstring,
}
# TODO add layer actions

if ! params["radius"]
  response["radius"] = radius
end

puts response.to_json
