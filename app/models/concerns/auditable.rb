# frozen_string_literal: true

# Gives ActiveRecord models an auditable behaviour
#
# Models with the Auditable behaviour automagically get their
# date_changed and changed_by field set to the currently logged
# in user.
#
# USAGE:
#  class ApplicationRecord < ActiveRecord::Model
#    include Auditable
#    ...
#  end
module Auditable
  extend ActiveSupport::Concern

  included do
    before_save :update_change_trail
    before_create :update_create_trail
  end

  # Saves current user after every save
  def update_change_trail
    unless respond_to?(:updated_by) && respond_to?(:updated_at)
      Rails.logger.warn "Auditable model missing updated_by or updated_date: #{self}"
      return
    end
    self.updated_by = User.current&.id
    self.updated_at = Time.now
  end

  def update_create_trail
    unless respond_to?(:created_at) && respond_to?(:creator) && respond_to?(:updated_at)
      Rails.logger.warn "Auditable model missing creator or created_at: #{self}"
      return
    end
    self.creator = User.current&.id if creator.nil? || creator.zero?
    Rails.logger.warn 'Auditable::update_create_trail called outside login' unless creator

    now = Time.now
    self.created_at = now
    self.updated_at = now
  end

  def auditable?
    respond_to?(:updated_by) && respond_to?(:updated_at)
  end
end
