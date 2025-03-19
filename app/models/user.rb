# frozen_string_literal: true

# User model
class User < ApplicationRecord
  before_create :set_app_uuid

  def self.current
    Thread.current['current_user']
  end

  def self.current=(user)
    Thread.current['current_user'] = user
  end

  private

  def set_app_uuid
    self.app_uuid ||= SecureRandom.uuid
  end
end
