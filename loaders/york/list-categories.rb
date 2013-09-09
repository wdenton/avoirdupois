#!/usr/bin/env ruby

require 'yaml'
require 'cgi'

require 'rubygems'
require 'json'

placemark_files = ["all_placemarks.js", "glendon_placemarks.js", "other_locations.js"]

categories = Hash.new

placemark_files.each do |placemark_file|
  begin
    json = JSON.parse(File.open(placemark_file).read)
  rescue Exception => e
    STDERR.puts e
    exit 1
  end

  json.each do |placemark|
    placemark["category"].each do |cat|
      if ! categories[cat]
        categories[cat] = []
      end
      categories[cat] << CGI.unescapeHTML(placemark["title"])
    end
    if placemark["category"].length > 1
       puts CGI.unescapeHTML(placemark["title"]) + "\t\t" + placemark["category"].join(",")
    end
  end

end

categories.each do |cat|
  puts cat[0]
  cat[1].each do |i|
    # puts "  #{i}"
  end
end



