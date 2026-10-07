# frozen_string_literal: true

# User model
class User < ApplicationRecord
  before_create :set_app_uuid
  has_and_belongs_to_many :roles
  validates :username, uniqueness: true, presence: true

  validates :mlab_callback_base_url,
              format: {
                with:  %r{\Ahttps?://[a-zA-Z0-9.-]+(?::\d+)?(?:/[^\s]*)?\z},
                message: 'must be a valid HTTP or HTTPS URL'
              },
              allow_blank: true

  validates  :mlab_callback_token, presence: true, if: :mlab_callback_enabled?
  validates :mlab_callback_base_url, presence: true, if: :mlab_callback_enabled?

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
