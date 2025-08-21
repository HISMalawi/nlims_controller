# frozen_string_literal: true

# Codeable module for setting nlims code and validations
module Codeable
  extend ActiveSupport::Concern

  included do
    # if column_names.include?('unit')
    #   validates :name, uniqueness: { scope: :unit, case_sensitive: false }, allow_nil: true
    # else
    #   validates :name, uniqueness: { case_sensitive: false }, allow_nil: false
    # end
    validates :nlims_code, uniqueness: { case_sensitive: false }, allow_nil: true unless name == 'Measure'

    after_create :set_nlims_code
  end

  private

  def set_nlims_code
    return if nlims_code.present?

    if is_a?(Measure)
      # Try reusing existing nlims_code from another Measure with same name
      existing = Measure.find_by(name: name)
      if existing&.nlims_code.present?
        update_column(:nlims_code, existing.nlims_code)
        return
      end
    end

    # Fallback to default generation
    prefix = self.class.const_defined?(:NLIMS_CODE_PREFIX) ? "NLIMS_#{self.class::NLIMS_CODE_PREFIX}_" : 'UNKNOWN_'
    update_column(:nlims_code, "#{prefix}#{id.to_s.rjust(4, '0')}_MWI")
  end
end
