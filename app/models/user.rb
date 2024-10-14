# frozen_string_literal: true

# User model
class User < ApplicationRecord
  before_create :set_app_uuid

  private

  def set_app_uuid
    self.app_uuid ||= SecureRandom.uuid
  end
end
