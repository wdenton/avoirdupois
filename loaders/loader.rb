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
  puts "Please specify one or more YAML file(s) containing POI data"
  exit
end

this_directory = File.dirname(__FILE__)

dbconfig = YAML::load(File.open("#{this_directory}/../config/database.yml"))[ENV['ENV'] ? ENV['ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob("#{this_directory}/../app/models/*.rb").each { |r| require r }

poi_files.each do |poi_file|

  begin
    config = YAML.load_file(poi_file)
  rescue Exception => e
    puts e
    exit 1
  end

  puts "Creating #{config['layer_name']} ..."

  option_value = 1

  #l = Layer.find_or_create_by_name(:name => layer_name,
  l = Layer.find_or_create_by(name: config['layer_name'],
    :refreshInterval => config["refreshInterval"],
    :refreshDistance => config["refreshDistance"],
    :fullRefresh => config["fullRefresh"],
    :showMessage => config["showMessage"],
    :biwStyle => config["biwStyle"],
    )

  if config['pois']
    config['pois'].each do |p|
      puts p['title']
      poi = Poi.create(
        :title               => p['title'],
        :description         => p['description'],
        :footnote            => p['footnote'],
        :lat                 => p['lat'].to_f,
        :lon                 => p['lon'].to_f,
        :imageURL            => p['imageURL'],
        :biwStyle            => p['biwStyle'] || "classic",
        :alt                 => p['alt'] || 0,
        :doNotIndex          => p['doNotIndex'] || 0,
        :showSmallBiw        => p['showSmallBiw'] || true,
        :showBiwOnClick      => p['showBiwOnClick'] || true,
        :poiType             => p['poiType'],
        )
      if p["actions"]
        p["actions"].each do |a|
          puts "  Action: " + a["label"]
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
      
      if p["icon"]
        puts "  Icon: " + p["icon"]["label"]
        poi.icon = Icon.create(
          :label            => p["icon"]['label'],
          :url              => p["icon"]['url'],
          :iconType         => p["icon"]['type'],
          )
      end
      
      if p["object"]
        puts "  Object: " + p["object"]["url"]
        poi.ubject = Ubject.create(
          :url              => p["object"]['url'],
          :contentType      => p["object"]['contentType'],
          :size             => p["object"]['size'],
          )
        
        if poi.ubject.contentType == "model/vnd.layar.l3d"
          poi.ubject.reducedURL    = p["object"]["reducedURL"]
        elsif poi.ubject.contentType == "text/html"
          poi.ubject.width       = p["object"]["width"]
          poi.ubject.height      = p["object"]["height"]
          poi.ubject.scrollable  = p["object"]["scrollable"]
          poi.ubject.interactive = p["object"]["interactive"]
        end
        poi.ubject.save
      end
      
      if p["transform"]
        puts "  Transform added"
        poi.transform = Transform.create(
          :rel              => p["transform"]['rel'],
          :angle            => p["transform"]['angle'],
          :rotate_x         => p["transform"]['rotate_x'],
          :rotate_y         => p["transform"]['rotate_y'],
          :rotate_z         => p["transform"]['rotate_z'],
          :translate_x      => p["transform"]['translate_x'],
          :translate_y      => p["transform"]['translate_y'],
          :translate_z      => p["transform"]['translate_x'],
          :scale            => p["transform"]['scale'],
          )
      end
      
      
      if p["checkbox"]
        p["checkbox"].each do |c|
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
  
  puts "Checkbox configuration for Layar:"
  Checkbox.all.each do |c|
    puts "#{c.option_value} | #{c.label}"
  end

  puts
  
end

