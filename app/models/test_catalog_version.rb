# frozen_string_literal: true

# TestCatalogVersion model class
class TestCatalogVersion < ApplicationRecord
  include Auditable
  before_create :set_version

  private

  def set_version
    last_version = TestCatalogVersion.last
    self.version = last_version.present? ? "v#{last_version.id + 1}" : 'v1'
  end
end
