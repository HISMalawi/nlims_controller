# frozen_string_literal: true

#  ward model
class Ward < ApplicationRecord
  def self.get_ward_id(type)
    Ward.find_or_create_by(name: type).id
  end
end
