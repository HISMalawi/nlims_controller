# frozen_string_literal: true

# Product model
class Product < ApplicationRecord
  include Codeable
  has_many :product_equipments, dependent: :destroy
  has_many :equipments, through: :product_equipments

  validates_uniqueness_of :name
  NLIMS_CODE_PREFIX = 'PROD'
end
