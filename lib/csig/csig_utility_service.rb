# frozen_string_literal: true

require 'csig/fpe_service'
require 'csig/mod9710_service'

# Central Specimen ID Generator utility service
module CsigUtilityService
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

  # Filter specimen identifications by distributed identifiers
  def self.filter_distributed(distributed)
    specimen_identifications = SpecimenIdentification.left_joins({ specimen_identification_distribution: :site })
                                                     .select('specimen_identifications.*, sites.name AS site_name,
                                                              sites.district')
    unless distributed.blank?
      specimen_identifications = specimen_identifications
                                 .where(distributed: ActiveRecord::Type::Boolean.new.cast(distributed))
    end
    specimen_identifications
  end

  # Search specimen identifications by sin
  def self.search_sin(sin, specimen_identifications)
    specimen_identifications = specimen_identifications.where("sin LIKE '%#{sin}%'") unless sin.blank?
    specimen_identifications
  end

  # rubocop:disable Metrics/MethodLength
  # Filter specimen identifications by status
  def self.filter_status(status, specimen_identifications)
    s = "SELECT ss.id FROM spid_statuses ss INNER JOIN
          (
            SELECT ss2.specimen_identification_id, MAX(ss2.created_at) created_at
            FROM spid_statuses ss2 GROUP BY ss2.specimen_identification_id
          ) ss_i ON ss.specimen_identification_id = ss_i.specimen_identification_id AND ss.created_at = ss_i.created_at"
    specimen_identifications = specimen_identifications
                               .joins({ specimen_identification_statuses: :csig_status })
                               .where("spid_statuses.id IN (#{s})").select('specimen_identifications.*,
                                csig_statuses.name AS status')
    unless status.blank?
      specimen_identifications = specimen_identifications
                                 .where("spid_statuses.csig_status_id = #{CsigStatus.find_by_name(status).id}")
    end
    specimen_identifications
  end

  # Search distributions using site name
  def self.search_site_name(site_name, distributions)
    distributions = distributions.where('sites.name LIKE ?', "%#{site_name}%") unless site_name.blank?
    distributions
  end

  # Page metadata
  def self.page_metadata(active_record_relation)
    if active_record_relation.empty?
      {
        total_pages: 0,
        current_page: 0,
        next_page: nil,
        prev_page: nil
      }
    else
      {
        total_pages: active_record_relation.total_pages,
        current_page: active_record_relation.current_page,
        next_page: active_record_relation.next_page,
        prev_page: active_record_relation.prev_page
      }
    end
  end
end
# rubocop:enable Metrics/MethodLength
