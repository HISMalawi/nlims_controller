# frozen_string_literal: true

require 'csig/reversing_service'
require 'csig/csig_utility_service'
# Central Specimen ID Generator Service
module CsigService
  def self.list_of_sins(per_page: 25, page_number: 1, distributed: nil, status: nil, query: nil)
    specimen_identifications = CsigUtilityService.filter_distributed(distributed)
    specimen_identifications = CsigUtilityService.search_sin(query, specimen_identifications)
    specimen_identifications = CsigUtilityService.filter_status(status, specimen_identifications)
    specimen_identifications = specimen_identifications.page(page_number).per(per_page) unless specimen_identifications.blank?
    {
      data: specimen_identifications,
      metadata: CsigUtilityService.page_metadata(specimen_identifications)
    }
  end

  def self.generate_sin(number_of_ids = 100)
    ids = []
    last_spid_transaction = SpecimenIdentification.last
    last_seq_number = last_spid_transaction.nil? ? 0 : last_spid_transaction.sequence_number.to_i
    next_seq_number = last_seq_number + 1
    0..number_of_ids.to_i.times do
      base9_equivalent = CsigUtilityService.convert_to_base9(next_seq_number)
      base9_equivalent_zero_padded = CsigUtilityService.prepad_number_with_zeros(10, base9_equivalent)
      fp_encrypted = CsigUtilityService.encrypt(base9_equivalent_zero_padded)
      fp_encrypted_zero_cleaned = CsigUtilityService.zero_cleaned(fp_encrypted)
      check_digit = Mod9710Service.calculate_check_digit(fp_encrypted_zero_cleaned)
      sin = CsigUtilityService.concat_check_digit_with_number(check_digit, fp_encrypted_zero_cleaned)
      ids << {
        sequence_number: next_seq_number,
        base9_equivalent: base9_equivalent,
        base9_zero_padded: base9_equivalent_zero_padded,
        encrypted: fp_encrypted,
        encrypted_zero_cleaned: fp_encrypted_zero_cleaned,
        check_digit: check_digit,
        sin: sin
      }
      next_seq_number += 1
    end
    SpecimenIdentification.import(ids)
    created_records = SpecimenIdentification.where("sequence_number > #{last_seq_number}")
    default_csig_status(created_records)
    created_records.limit(100)
  end

  def self.default_csig_status(created_records)
    csig_status = CsigStatus.find_by(name: 'Not Distributed')
    statuses = []
    created_records.each do |record|
      statuses << {
        csig_status_id: csig_status.id,
        specimen_identification_id: record.id
      }
    end
    SpecimenIdentificationStatus.import(statuses)
  end

  # Distrubute specimen identifications to sites
  # Refactor to use bulk insert
  def self.distribute_sin(number_of_ids = 100, site)
    sin_to_distribute = SpecimenIdentification.where(distributed: false).limit(number_of_ids)
    csig_status = CsigStatus.find_by(name: 'Distributed')
    ActiveRecord::Base.transaction do
      sin_to_distribute.each do |sin|
        SpecimenIdentificationDistribution.create(specimen_identification_id: sin.id, site_id: site.id)
        sin.update(distributed: true)
        SpecimenIdentificationStatus.create(
          csig_status_id: csig_status.id,
          specimen_identification_id: sin.id,
          site_name: site.name
        )
      end
    end
  end

  # Update this function so that chaning specimen identification status to - Used / Invalid should
  # used seq number and not sin as the allocated site/ system will be local keeping seq number
  # and sending seq number to central
  def self.use_sin(sin, site_name, system_name = nil)
    sin_used = sin_used?(sin)
    return true if sin_used

    sin_ = SpecimenIdentification.find_by(sin: sin)
    return 'Invalid sin' if sin_.nil?

    csig_status = CsigStatus.find_by(name: 'Used')
    spid_status = SpecimenIdentificationStatus.create(
      csig_status_id: csig_status.id,
      specimen_identification_id: sin_.id,
      site_name: site_name,
      system_name: system_name
    )
    if spid_status
      ActionCable.server.broadcast(
        'csig_sample_mapping_alert_channel',
        {
          data: sin_.sin,
          message: 'Sin is used'
        }
      )
    end
    spid_status
  end

  # check if a sin has been used
  def self.sin_used?(sin)
    sin_ = SpecimenIdentification.find_by(sin: sin)
    return false if sin_.nil?

    specimen_identification_status = SpecimenIdentificationStatus.where(specimen_identification_id: sin_.id).last
    return false if specimen_identification_status.nil?

    specimen_identification_status.csig_status.name == 'Used'
  end
end
