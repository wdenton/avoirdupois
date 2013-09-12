#!/usr/bin/env ruby

require 'open-uri'
require 'json'

# Keele: 
# Glendon: 

placemark_files = [
  "http://www.yorku.ca/web/maps/kml/all_placemarks.js",
  "http://www.yorku.ca/web/maps/kml/glendon_placemarks.js"
]

features = []

placemark_files.each do |url|

  markers = JSON.parse(open(url).read)

  markers.each do |marker|

    properties = {
      "ID" => marker["ID"],
      "title" => marker["title"],
      "content" => marker["content"],
      "building_code" => marker["building_code"],
      "category" => marker["category"]
    }

    geometry = {
      "type"        => "Point",
      "coordinates" => [marker["longitude"][0].to_f, marker["latitude"][0].to_f],
    }


    feature = {
      "type"       => "Feature",
      "properties" => properties,
      "geometry"   => geometry
    }


    features << feature
    
  end

end

puts features.to_json

