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

poi_files = ARGV
if poi_files.nil?
  puts "Please specify one or more GeoJSON files containing POI data"
  exit
end

this_directory = File.dirname(__FILE__)

dbconfig = YAML::load(File.open("#{this_directory}/../config/database.yml"))[ENV['RACK_ENV'] ? ENV['RACK_ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob("#{this_directory}/../app/models/*.rb").each { |r| require r }

poi_files.each do |poi_file|

  begin
    config = JSON.parse(File.read(poi_file))
  rescue Exception => e
    puts e
    exit 1
  end

  puts "Creating #{config['configuration']['layer_name']} ..."

  option_value = 1

  l = Layer.find_or_create_by(name: config['configuration']['layer_name'],
                              :refreshInterval => config['configuration']["refreshInterval"],
                              :refreshDistance => config['configuration']["refreshDistance"],
                              :fullRefresh     => config['configuration']["fullRefresh"],
                              :showMessage     => config['configuration']["showMessage"],
                              :biwStyle        => config['configuration']["biwStyle"],
                              )
  
  if config['features']
    config['features'].each do |p|
      puts p['properties']['title']
      poi = Poi.create(
        :title               => p['properties']['title'],
        :description         => p['properties']['description'],
        :footnote            => p['properties']['footnote'],
        :lat                 => p['geometry']['coordinates'][1].to_f,
        :lon                 => p['geometry']['coordinates'][0].to_f,
        :imageURL            => p['properties']['imageURL'],
        :biwStyle            => p['properties']['biwStyle'] || "classic",
        :alt                 => p['geometry']['coordinates'][2].to_f || 0,
        :doNotIndex          => p['properties']['doNotIndex'] || 0,
        :showSmallBiw        => p['properties']['showSmallBiw'] || true,
        :showBiwOnClick      => p['properties']['showBiwOnClick'] || true,
        :poiType             => p['properties']['poiType'],
        )
      if p['properties']["actions"]
        p['properties']["actions"].each do |a|
          puts "  Action: #{a['label']}"
          action = Action.create(
            :label            => a['label'],
            :uri              => a['uri'],
            :autoTriggerRange => a['autoTriggerRange'] || "",
            :autoTriggerOnly  => a['autoTriggerOnly']  || "",
            :contentType      => a['contentType']      || "application/vnd.layar.internal",
            :method           => a['method']           || "GET",
            :activityType     => a['activityType']     || 1,
            :params           => a['params']           || "",
            :closeBiw         => a['closeBiw']         || 0,
            :showActivity     => a['showActivity']     || true,
            :activityMessage  => a['activityMessage']  || "",
            :autoTrigger      => a['autoTrigger']      || false,
            )
          poi.actions << action
        end
      end
      
      if p['properties']["icon"]
        puts "  Icon: " + p['properties']["icon"]["label"]
        poi.icon = Icon.create(
          :label            => p['properties']["icon"]['label'],
          :url              => p['properties']["icon"]['url'],
          :iconType         => p['properties']["icon"]['type'],
          )
      end
      
      if p['properties']["object"]
        puts "  Object: " + p['properties']["object"]["url"]
        poi.ubject = Ubject.create(
          :url              => p['properties']["object"]['url'],
          :contentType      => p['properties']["object"]['contentType'],
          :size             => p['properties']["object"]['size'],
          )
        
        if poi.ubject.contentType == "model/vnd.layar.l3d"
          poi.ubject.reducedURL    = p['properties']["object"]["reducedURL"]
        elsif poi.ubject.contentType == "text/html"
          poi.ubject.width       = p['properties']["object"]["width"]
          poi.ubject.height      = p['properties']["object"]["height"]
          poi.ubject.scrollable  = p['properties']["object"]["scrollable"]
          poi.ubject.interactive = p['properties']["object"]["interactive"]
        end
        poi.ubject.save
      end
      
      if p['properties']["transform"]
        puts "  Transform added"
        poi.transform = Transform.create(
          :rel              => p['properties']["transform"]['rel'],
          :angle            => p['properties']["transform"]['angle'],
          :rotate_x         => p['properties']["transform"]['rotate_x'],
          :rotate_y         => p['properties']["transform"]['rotate_y'],
          :rotate_z         => p['properties']["transform"]['rotate_z'],
          :translate_x      => p['properties']["transform"]['translate_x'],
          :translate_y      => p['properties']["transform"]['translate_y'],
          :translate_z      => p['properties']["transform"]['translate_x'],
          :scale            => p['properties']["transform"]['scale'],
          )
      end
      
      if p['properties']["checkbox"]
        p['properties']["checkbox"].each do |c|
          puts "  Checkbox: " + c
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

  if l.checkboxes.empty?
    puts "No checkboxes to configure"
  else
    puts "Checkbox configuration for Layar:"
    l.checkboxes.each do |c|
      puts c
      puts "#{c.option_value} | #{c.label}"
    end
  end
  
end

