# frozen_string_literal: true

# Config Model containing system configurations
class Config < ApplicationRecord
  validates :config_type, presence: true, uniqueness: true

  def self.local_nlims?
    find_by(config_type: 'nlims_host')&.configs&.dig('local_nlims')
  end

  def self.configurations(config_type)
    find_by(config_type:)&.configs
  end

  def self.same_source?(tracking_number)
    host = TrackingNumberHost.find_by(tracking_number:)
    return false unless host

    host&.source_host == host&.update_host && host&.source_app_uuid == host&.update_app_uuid
  end

  def self.master_update_source?(tracking_number)
    host = TrackingNumberHost.find_by(tracking_number:)
    return false unless host

    User.find_by(app_uuid: host&.update_app_uuid)&.app_name == 'MASTER NLIMS'
  end
end
