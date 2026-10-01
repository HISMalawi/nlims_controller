# frozen_string_literal: true

# Connect to mlab db
class MlabBase < ActiveRecord::Base
  self.abstract_class = true

  def self.configured?
    configurations.configs_for(env_name: Rails.env, name: 'mlab').present?
  end

  establish_connection(:mlab) if configured?
  self.table_name = 'orders'
end
