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

require 'rubygems'
require 'active_record'

require 'yaml'
require 'cgi'
require 'json'

this_directory = File.dirname(__FILE__)

dbconfig = YAML::load(File.open("#{this_directory}/../../config/database.yml"))[ENV['RACK_ENV'] ? ENV['RACK_ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob("#{this_directory}/../../app/models/*.rb").each { |r| require r }

supplemental_file = "york-supplemental.yaml"

# Icons and images
parking_icon_url      = "http://avoirdupois.miskatonic.org/icons/yorkuniversitytoronto/york-ciw-parking-110px.png" # "Parking"" in a white circle
parking_poi_image_url = parking_icon_url # Use it in BIW bar, too (it will be scaled down)
york_icon_url         = "http://avoirdupois.miskatonic.org/icons/yorkuniversitytoronto/york-ciw-110x110.png" # York social media logo (square)
york_poi_image_url    = "http://www.yorku.ca/web/css/yeb11yorklogo.gif" # Standard York logo

# TODO: Load this in live (or accept as option if local?)
# Keele: http://www.yorku.ca/web/maps/kml/all_placemarks.js
# Glendon: http://www.yorku.ca/web/maps/kml/glendon_placemarks.js

# None of this data is here:
#  Emergency phones: http://www.yorku.ca/web/maps/kml/Emergency-Phones.kml
#  Wheeltrans: http://www.yorku.ca/web/maps/kml/Wheeltrans.kml
#  GoSafe: http://www.yorku.ca/web/maps/kml/go-safe.kmz
#  Shuttle: http://www.yorku.ca/web/maps/kml/Shuttle.kml
#  YRT: http://www.yorku.ca/web/maps/kml/yrt-transit.kml
#  Pickup: http://www.yorku.ca/web/maps/kml/Pickup.kmz
#  Glendon TTC: http://www.yorku.ca/web/maps/kml/glendon-ttc.kml

# TODO:
#  Would it be useful to convert the JSON into GeoJSON?

placemark_files = ["all_placemarks.js", "glendon_placemarks.js", "other_locations.js"]

# Also need to add:
# Miles S. Nadal Management Centre
# Innovation York
# Osgoode Professional Development Centre

begin
  supplemental = YAML.load_file(supplemental_file)
rescue Exception => e
  STDERR.puts e
  exit 1
end

l = Layer.find_or_create_by(name: "yorkuniversitytoronto",
  :refreshInterval => 300,
  :refreshDistance => 100,
  :fullRefresh => true,
  :showMessage => "Filters are available through Layer Actions in settings.",
  :biwStyle => "classic",
  )

option_value = 1

placemark_files.each do |placemark_file|

  begin
    json = JSON.parse(File.open(placemark_file).read)
  rescue Exception => e
    STDERR.puts e
    exit 1
  end

  json.each do |placemark|

    poi = Poi.new
    poi.yorknum = placemark["ID"]
    poi.title = CGI.unescapeHTML(placemark["title"])
    STDERR.puts poi.title

    # If there's any supplemental information about this site, get ready to use it.
    supp = supplemental.fetch(poi["title"], nil)

    #  puts poi["title"]
    # The content field is a chunk of HTML. We want to just use what's inside the <address> tags, but not the first such chunk because
    # it's the name of the place, and then we want to trim the length of the text to 140 characters.  A bit ugly.
    content = placemark["content"].match(/<address>(.*)<.+address>/) # Get all content from first <address> to last <\\/address>
    if content.nil?
      poi.description = ""
    else
      # Split, ignore the first chunk, join all the rest, and trim
      poi.description = content[1].split("</address><address>").slice(1..-1).join("; ").slice(0, 135)
    end

    # If we defined a description in the supplemental file, use it.
    if supp and supp["description"]
      poi.description = supp["description"]
    end

    poi.footnote = ""
    poi.lat = placemark["latitude"][0].to_s
    poi.lon = placemark["longitude"][0].to_s

    # Images (in the BIW bar) and icons (floating in space)
    # The placemarks file has images for some sites on campus, but not all.  Grab it if it's there and use it.
    grabbedimage = placemark["content"].match(/src=\"(.*jpg)/)
    icon = Icon.new
    if grabbedimage.nil?
      # If it isn't there, use the standard York logo for the icon in the bar,
      # and further, if the location happens to be a parking lot, use a special parking icon.
      if placemark["category"].any? {|c| c.match(/parking/i)}
        icon.url = parking_icon_url
        poi.imageURL = parking_poi_image_url
      else
        icon.url = york_icon_url
        poi.imageURL = york_poi_image_url
        STDERR.puts "  default icon"
      end
    else
      poi.imageURL = grabbedimage[1].gsub(/\\\//, "/") # Turn http:\/\/foo\/bar into http://foo/bar
      icon.url = poi.imageURL
    end
    # STDERR.puts "  icon: #{icon["url"]}"
    poi.icon = icon

    poi.biwStyle = "collapsed" # "classic" or "collapsed"
    poi.alt = 0
    poi.doNotIndex = 0
    poi.showSmallBiw = 1
    poi.showBiwOnClick = 1
    poi.poiType = "geo"

    action = Action.new
    # TODO Should add link to http://www.yorku.ca/parking/ for all parking lots
    if supp and supp["action"] # There is an action for this location
      STDERR.puts "  URL: #{supp["action"]["url"]}"
      action.label = supp["action"]["label"]
      action.uri = supp["action"]["url"]
      action.contentType = "application/vnd.layar.internal"
      action.method = "GET"
      action.activityType = 1
      action.params = ""
      action.closeBiw = 0
      action.showActivity = 1
      action.activityMessage = ""
      action.autoTrigger = false
      poi.actions << action
    end

    if placemark["category"].any?
      placemark["category"].each do |c|
        STDERR.puts "  Category: #{c}"
        cat = Checkbox.find_by_label(c)
        if cat.nil?
          cat = Checkbox.create(:label => c, :option_value => option_value)
          option_value += 1
        end
        poi.checkboxes << cat
      end
    end

    l.pois << poi
  end
end

puts "Checkbox configuration for Layar:"
Checkbox.all.each do |c|
  puts "#{c.option_value} | #{c.label}"
end
