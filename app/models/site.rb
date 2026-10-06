# frozen_string_literal: true

# Site (health facility) that sends orders to NLIMS
class Site < ApplicationRecord
  LOCAL_NLIMS = 'local_nlims'
  CENTRAL_EMR = 'central_emr'
  INTEGRATION_MODES = [LOCAL_NLIMS, CENTRAL_EMR].freeze

  has_paper_trail
  belongs_to :emr_instance, optional: true

  # Blank strings would collide on the unique indexes for these columns
  normalizes :other_name, :mahis_facility_code, :host_address, :application_port,
             with: ->(value) { value.strip.presence }

  validates :integration_mode, inclusion: { in: INTEGRATION_MODES }
  validates :mahis_location_id, uniqueness: true, allow_nil: true
  validates :mahis_facility_code, uniqueness: true, allow_nil: true
  validate :central_emr_requirements, if: :central_emr?

  before_save :stamp_integration_mode_change, if: :integration_mode_changed?

  scope :enabled, -> { where(enabled: true) }

  def central_emr?
    integration_mode == CENTRAL_EMR
  end

  def local_nlims?
    integration_mode == LOCAL_NLIMS
  end

  private

  def central_emr_requirements
    errors.add(:emr_instance, 'must be selected for central EMR sites') if emr_instance.blank?
    errors.add(:mahis_location_id, 'is required for central EMR sites') if mahis_location_id.blank?
  end

  def stamp_integration_mode_change
    self.integration_mode_changed_at = Time.now
  end
end
