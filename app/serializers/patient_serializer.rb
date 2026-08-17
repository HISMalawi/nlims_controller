# frozen_string_literal: true

# One patient as every API renders them.
class PatientSerializer
  def self.call(patient)
    {
      uuid: patient.uuid,
      national_id: patient.national_id,
      name: patient.name,
      sex: patient.sex,
      birthdate: patient.birthdate&.iso8601,
      phone: patient.phone
    }
  end
end
