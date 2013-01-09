class Layer < ActiveRecord::Base
  has_many :pois, :dependent => :destroy
end
