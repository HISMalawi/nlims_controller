# frozen_string_literal: true

# Equipment model
class Equipment < ApplicationRecord
  include Codeable
  has_many :product_equipments, dependent: :destroy
  has_many :products, through: :product_equipments
  has_and_belongs_to_many :test_types
  has_paper_trail

  validates_uniqueness_of :name

  NLIMS_CODE_PREFIX = 'EQP'

  def as_json(options = {})
    super(options.merge(
      except: %i[],
      include: {
        products: {}
      }
    ))
  end
end
