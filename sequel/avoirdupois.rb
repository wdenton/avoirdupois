#!/usr/bin/env ruby

# require 'rubygems'
$RUBY_LIB << "."

require 'sequel'

DB = Sequel.connect("sqlite://avoirdupois.db")

# Note: use TrueClass (or FalseClass) to make a Boolean field

require './model.rb'

# l = Layer.create(:layer => "Hello Again")
# p = l.add_poi(:title => "Foo 2", :lat => 10, :lon => 10)

p = Poi.find(:id => 1)

puts "Content-type: text/plain"
puts
puts p.title
