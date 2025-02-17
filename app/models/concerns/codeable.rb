# frozen_string_literal: true

# Codeable module for setting nlims code and validations
module Codeable
  extend ActiveSupport::Concern

  included do
    validates :name, uniqueness: { case_sensitive: false }, allow_nil: true
    validates :nlims_code, uniqueness: { case_sensitive: false }, allow_nil: true
    validates :moh_code, uniqueness: { case_sensitive: false }, allow_nil: true
    validates :loinc_code, uniqueness: { case_sensitive: false }, allow_nil: true

    after_create :set_nlims_code
  end

  private

  def set_nlims_code
    return if nlims_code.present?

    prefix = self.class.const_defined?(:NLIMS_CODE_PREFIX) ? self.class::NLIMS_CODE_PREFIX : 'UNKNOWN'
    update_column(:nlims_code, "#{prefix}#{id}MW")
  end
end
