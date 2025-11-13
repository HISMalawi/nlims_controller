# frozen_string_literal: true

# ProductEquipment model
class ProductEquipment < ApplicationRecord
  belongs_to :product
  belongs_to :equipment
end
