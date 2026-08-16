# frozen_string_literal: true

# A stable identifier that survives re-seeds and crosses node boundaries.
# Auto-increment ids never leave this database.
module HasUuid
  extend ActiveSupport::Concern

  included do
    before_create :assign_uuid
  end

  private

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
