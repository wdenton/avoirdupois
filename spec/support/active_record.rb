require 'rubygems'
require 'active_record'
require 'rspec/rails/extensions/active_record/base'

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
load "./initialize.rb"

RSpec.configure do |config|
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end


