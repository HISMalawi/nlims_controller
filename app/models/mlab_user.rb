# frozen_string_literal: true

# MlabUser model - reads from mlab database users table
class MlabUser < MlabBase
  self.table_name = 'users'

  belongs_to :mlab_person, foreign_key: 'person_id', class_name: 'MlabPerson', optional: true

  scope :not_voided, -> { where('users.voided IS NULL OR users.voided = 0') }
  scope :not_retired, -> { where('users.retired IS NULL OR users.retired = 0') }
end
