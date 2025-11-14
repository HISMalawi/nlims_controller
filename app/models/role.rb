# frozen_string_literal: true

# Role model
class Role < ApplicationRecord
  has_and_belongs_to_many :users

  validates :name, uniqueness: true, presence: true
end
