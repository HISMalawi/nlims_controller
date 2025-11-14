# frozen_string_literal: true

# Connect to mlab db
class MlabBase < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(:mlab)
  self.table_name = 'orders'
end
