#!/usr/bin/env ruby

class Layer < Sequel::Model
  one_to_many :pois
end

class Poi < Sequel::Model
  many_to_one :layer
  many_to_one :icon
  many_to_one :action
  many_to_one :transform
  many_to_one :ubject
end

class Icon < Sequel::Model
  one_to_many :pois
end

class Ubject < Sequel::Model
  one_to_many :pois
end

class Action < Sequel::Model
  one_to_many :pois
end

class Transform < Sequel::Model
  one_to_many :pois
end

