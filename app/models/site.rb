# frozen_string_literal: true

# Site model
class Site < ApplicationRecord
  def self.search(name)
    where("name LIKE ?", "%#{name}%")
  end
end
