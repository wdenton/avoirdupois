#!/usr/bin/env ruby

require 'rubygems'
require 'sequel'

DB = Sequel.connect("sqlite://avoirdupois.db")

# Note: use TrueClass (or FalseClass) to make a Boolean field

DB.create_table!(:layers) do
  primary_key :id
  String      :layer,            :null => false
  Integer     :refreshInterval,  :default => 300
  Integer     :refreshDistance,  :default => 100
  TrueClass   :fullRefresh,      :default => true
  String      :showMessage
  String      :biwStyle
end

DB.create_table!(:pois) do
  primary_key :id
  foreign_key :layer_id,        :layers
  foreign_key :icon_id,         :icons
  foreign_key :action_id,       :actions
  foreign_key :transform_id,    :transforms
  foreign_key :ubject_id,       :ubjects
  Int         :york_id
  String      :title,           :null => false
  String      :description
  String      :footnote
  Float       :lat,             :null=> false
  Float       :lon,             :null=> false
  String      :imageURL
  String      :biwStyle,        :default => "classic"
  Float       :alt,             :default => 0
  Integer     :doNotIndex,      :default => 0
  TrueClass   :showSmallBiw,    :default => true
  TrueClass   :showBiwOnClick,  :default => true
  String      :poiType,         :null => false, :default => "geo"
end

DB.create_table!(:icons) do
  primary_key :id
  String      :label
  String      :url,             :null => false
  Integer     :type,            :null => false, :default => 0
end

DB.create_table!(:actions) do
  primary_key :id
  String      :poiID,           :null => false
  String      :label,           :null => false
  String      :uri,             :null => false
  String      :contentType,     :default => "application/vnd.layar.internal"
  String      :method,          :default => "GET"   # "GET", "POST"
  Integer     :activityType,    :deault => 1
  String      :params
  TrueClass   :closeBiw,        :default => false
  TrueClass   :showActivity,    :default => false
  String      :activityMessage
  TrueClass   :autoTrigger,     :required => true, :default => false
  Integer     :autoTriggerRange
  TrueClass   :autoTriggerOnly, :default => false
end

DB.create_table!(:ubjects) do
  primary_key :id
  String      :url,             :null => false
  String      :reducedUrl,      :null => false
  String      :contentType,     :null => false
  Float       :size,            :null => false
end

DB.create_table!(:transforms) do
  primary_key :id
  Integer     :rel,             :default => 0
  BigDecimal  :angle,           :size => [5, 2], :default => 0.00
  BigDecimal  :rotate_x,        :size => [2, 1], :default => 0.0
  BigDecimal  :rotate_y,        :size => [2, 1], :default => 0.0
  BigDecimal  :rotate_z,        :size => [2, 1], :default => 1.0
  BigDecimal  :translate_x,     :size => [2, 1], :default => 0.0
  BigDecimal  :translate_y,     :size => [2, 1], :default => 0.0
  BigDecimal  :translate_z,     :size => [2, 1], :default => 0.0
  BigDecimal  :scale,           :size => [12, 2], :default => 1.0
end

l = Layer.create(:layer => "Hello")
p = l.add_poi(:title => "Foo", :lat => 10, :lon => 10)
