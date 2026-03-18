# frozen_string_literal: true

# MlabSpecimen model - reads from mlab database specimens table
# NOTE: In mlab, the specimens table is equivalent to nlims' specimen_types table
# It contains: id, name, nlims_code, description, etc.
class MlabSpecimen < MlabBase
  self.table_name = 'specimen'

  has_many :mlab_tests, foreign_key: 'specimen_id', class_name: 'MlabTest'

  scope :not_retired, -> { where('specimen.retired IS NULL OR specimen.retired = 0') }
end
