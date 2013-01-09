class Poi < ActiveRecord::Base
  belongs_to :layer
  has_one    :icon, :dependent => :destroy
  has_many   :actions, :dependent => :destroy
  has_one    :ubject, :dependent => :destroy
  has_one    :transform, :dependent => :destroy
  has_and_belongs_to_many :checkboxes

  # This method lets us use the checkbox filter.
  # If an array of checkbox option values from Layer is passed in,
  # this will return all the POIs that match.  If the array is empty,
  # it will return all POIs.  Hence this method can always be used,
  # and it will only take effect when needed.  (Though if you're not
  # using the checkbox filter at all, you can leave it out.)
  def self.checkboxed(checkmarks)
    if checkmarks.empty?
      return all
    else
      joins("INNER JOIN checkboxes c, checkboxes_pois c_p").where("c_p.poi_id = pois.id AND c_p.checkbox_id = c.id AND c.option_value IN (?)", checkmarks)
      # Without a GROUP BY the same POI will be return more than once if it matches more than one checkmark.  This is handled by the group(:id)
      # filter when this method is called.
    end
  end

  def within_radius(latitude, longitude, radius)
    distance(latitude, longitude) <= radius
  end

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

end
