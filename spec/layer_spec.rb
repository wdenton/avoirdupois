require 'test/unit'

require '../app/models/layer.rb'



describe Layer do
  describe "name" do
    it "requires a name" do
      layer.name = ""
      layer.should have(1).error_on(:name)
    end
  end
end

