# frozen_string_literal: true

require 'csig/fpe_service'
require 'csig/mod9710_service'
# Central Specimen ID Generator Service
module CsigService
  def self.list_of_sins(per_page: 25, page_number: 1, distributed: nil, status: nil, query: nil)
    specimen_identifications = filter_distributed(distributed)
    specimen_identifications = search_sin(query, specimen_identifications)
    specimen_identifications = filter_status(status, specimen_identifications)
    specimen_identifications.page(page_number).per(per_page) unless specimen_identifications.nil?
  end

  def self.filter_distributed(distributed)
    specimen_identifications = SpecimenIdentification.left_joins({specimen_identification_distribution: :site}).select('specimen_identifications.*, sites.name AS site_name, sites.district')
    specimen_identifications = specimen_identifications.where(distributed: distributed)  unless distributed.nil?
    specimen_identifications
  end

  def self.search_sin(sin, specimen_identifications)
    specimen_identifications = specimen_identifications.where("sin LIKE #{sin}") unless sin.nil?
    specimen_identifications
  end

  def self.filter_status(status, specimen_identifications)
    s = SpecimenIdentification.joins(:specimen_identification_statuses).select('MAX(specimen_identifications.created_at)').group('specimen_identifications.id')
    specimen_identifications = specimen_identifications.joins({specimen_identification_statuses: :csig_status}).where("specimen_identifications.created_at IN (#{s.to_sql})"
    ).select('specimen_identifications.*, csig_statuses.name AS status')
    specimen_identifications = specimen_identifications.where("spid_statuses.csig_status_id = #{status}") unless status.nil?
    specimen_identifications
  end

  def page_metadata(active_record_relation)
    {
      total_pages: active_record_relation.total_pages,
      current_page: active_record_relation.current_page,
      next_page: active_record_relation.next_page,

    }
  end

  def self.generate_sin(number_of_ids = 100)
    ids = []
    last_spid_transaction = SpecimenIdentification.last
    last_seq_number = last_spid_transaction.nil? ? 0 : last_spid_transaction.sequence_number.to_i
    next_seq_number = last_seq_number + 1
    0..number_of_ids.to_i.times do
      base9_equivalent = convert_to_base9(next_seq_number)
      base9_equivalent_zero_padded = prepad_number_with_zeros(10, base9_equivalent)
      fp_encrypted = encrypt(base9_equivalent_zero_padded)
      fp_encrypted_zero_cleaned = zero_cleaned(fp_encrypted)
      check_digit = Mod9710Service.calculate_check_digit(fp_encrypted_zero_cleaned)
      sin = concat_check_digit_with_number(check_digit, fp_encrypted_zero_cleaned)
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
    SpecimenIdentification.where("sequence_number > #{last_seq_number}").limit(100)
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

  # Update specimen identification status to - Used / Invalid(Not allocated to the site/ should send seq number to central)
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

  # Encrypt a number using FPE FF3
  def self.encrypt(plaintext)
    fpe_service.encrypt(plaintext.to_s)
  end

  # Decrypt a ciphernumber using FPE FF3
  def self.decrypt(ciphertext)
    fpe_service.decrypt(ciphertext)
  end

  # Convert a number to base 9
  def self.convert_to_base9(number)
    return number if number < 9

    result = ''
    while number != 0
      result = (number % 9).to_s + result
      number /= 9
    end
    result.to_i
  end

  # Prepad a number with 0s to a given length
  def self.prepad_number_with_zeros(length = 10, number)
    number.to_s.rjust(length, '0')
  end

  # To Follow up: Why concat check digit to the left of the number?
  def self.concat_check_digit_with_number(check_digit, number)
    check_digit.to_s + number.to_s
  end

  # clean zeros by adding 1 to each individual value in the number
  def self.zero_cleaned(number)
    numbers = number.to_i.digits.reverse
    numbers.map { |n| n + 1 }.join.to_i
  end

  # FPE service
  def self.fpe_service
    encryption_key = ENV['KEY']
    tweak_value = ENV['TWEAK']
    radix = ENV['RADIX'].to_i
    alphabet = ENV['ALPHABET']
    FF3Cipher.new(encryption_key, tweak_value, radix, alphabet)
  end
end
