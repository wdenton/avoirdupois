class Poi < ActiveRecord::Base
  belongs_to :layer
  has_one    :icon
  has_many   :actions
  has_one    :ubject
  has_one    :transform

  def distance(latitude, longitude)

    # poi.distance(latitude, longitude) = distance from the POI to that point

    # Taken from https://github.com/almartin/Ruby-Haversine/blob/master/haversine.rb
    # https://github.com/almartin/Ruby-Haversine
    earthRadius = 6371 # Earth's radius in km

    # convert degrees to radians
    def convDegRad(value)
      unless value.nil? or value == 0
        value = (value/180) * Math::PI
      end
      return value
    end

    deltaLat = (self.lat - latitude)
    deltaLon = (self.lon - longitude)
    deltaLat = convDegRad(deltaLat)
    deltaLon = convDegRad(deltaLon)

    # Calculate square of half the chord length between latitude and longitude
    a = Math.sin(deltaLat/2) * Math.sin(deltaLat/2) +
      Math.cos((self.lat/180 * Math::PI)) * Math.cos((latitude/180 * Math::PI)) *
      Math.sin(deltaLon/2) * Math.sin(deltaLon/2);
    # Calculate the angular distance in radians
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))

    distance = earthRadius * c * 1000 # meters
    return distance
  end

  def within_radius(latitude, longitude, radius)
    distance(latitude, longitude) <= radius
  end

end

