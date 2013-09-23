class Layer < ActiveRecord::Base
  has_many :pois, :dependent => :destroy

  def has_checkboxes
    # There must be a better way to determine if any of the POIs belong to a given layer have checkboxes.
    number_of_checkboxes = Checkbox.find_by_sql(["select c.id from checkboxes c INNER JOIN pois p INNER JOIN checkboxes_pois cp WHERE cp.checkbox_id = c.id AND cp.poi_id = p.id AND p.layer_id = ? GROUP BY c.id", self.id]).size
    return number_of_checkboxes > 0 ? true : false
  end

    def checkboxes
      # There must be a better way to determine if any of the POIs belong to a given layer have checkboxes.
      checkboxes = Checkbox.find_by_sql(["select c.id from checkboxes c INNER JOIN pois p INNER JOIN checkboxes_pois cp WHERE cp.checkbox_id = c.id AND cp.poi_id = p.id AND p.layer_id = ? GROUP BY c.id", self.id])
      return checkboxes
  end
  
end
