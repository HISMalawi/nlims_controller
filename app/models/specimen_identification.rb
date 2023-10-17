# frozen_string_literal: true

require 'activerecord-import/base'
require 'activerecord-import/active_record/adapters/mysql2_adapter'
# specimen_identification model
class SpecimenIdentification < ApplicationRecord
  validates :sequence_number, presence: true, uniqueness: true
  validates :base9_equivalent, presence: true, uniqueness: true
  validates :base9_zero_padded, presence: true, uniqueness: true
  validates :encrypted, presence: true, uniqueness: true
  validates :sin, presence: true, uniqueness: true
  validates :check_digit, presence: true
  validates :encrypted_zero_cleaned, presence: true, uniqueness: true
  has_many :specimen_identification_statuses
  after_create :default_specimen_identification_status
  has_one :specimen_identification_distribution

  private

  def default_specimen_identification_status
    csig_status = CsigStatus.find_by(name: 'Not Distributed')
    SpecimenIdentificationStatus.create(csig_status_id: csig_status.id, specimen_identification_id: id)
  end
end
