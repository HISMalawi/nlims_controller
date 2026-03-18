# frozen_string_literal: true

# MlabPerson model - reads from mlab database people table
class MlabPerson < MlabBase
  self.table_name = 'people'

  has_one :mlab_client, foreign_key: 'person_id', class_name: 'MlabClient'

  scope :not_voided, -> { where('people.voided IS NULL OR people.voided = 0') }

  def full_name
    [given_name, middle_name, family_name].compact.join(' ')
  end
end
