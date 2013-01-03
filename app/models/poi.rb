class Poi < ActiveRecord::Base
  belongs_to :layers
  has_many :actions
  has_many :ubjects
end

