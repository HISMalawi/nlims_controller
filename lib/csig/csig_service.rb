# frozen_string_literal: true

require 'csig/reversing_service'
require 'csig/csig_utility_service'
# Central Specimen ID Generator Service
module CsigService

  # get csgi analytics
  def self.analytics
    specimens = SpecimenIdentification.all
    distributions = SpecimenIdentificationDistribution
      .joins(:site, :specimen_identification)
      .select('sites.name as site_name, COUNT(*) as count_of_specimens')
      .group('site_name')
      .take(5)
    facilities = Site.count
    sites_count = SpecimenIdentificationDistribution
      .joins(:site)
      .select('COUNT(DISTINCT sites.name) as site_count')
      .first.site_count
    total_distributions = SpecimenIdentificationDistribution.count
    generated_last_at = SpecimenIdentificationDistribution.order(updated_at: :desc).first&.updated_at
    statuses = CsigStatus.all
    statuses_data = statuses.each_with_object({}) do |status, hash|
      hash[status.name] = CsigUtilityService.filter_status(status.name, specimens).size
    end
    distributions_by_status = {
      "Not Distributed": statuses_data["Not Distributed"] - statuses_data["Distributed"],
      "Distributed": statuses_data["Distributed"],
      "Used": statuses_data["Used"],
    }
    {
      specimens_count: specimens.count,
      distributions: distributions,
      distribution_sites: sites_count,
      distributions_total: total_distributions,
      distributions_by_status: distributions_by_status,
      generated_last_at: generated_last_at,
      sites: facilities,
      updated_at: DateTime.now
    }
  end

  def self.list_of_sins(per_page: 25, page_number: 1, distributed: nil, status: nil, query: nil)
    specimen_identifications = CsigUtilityService.filter_distributed(distributed)
    specimen_identifications = CsigUtilityService.search_sin(query, specimen_identifications)
    specimen_identifications = CsigUtilityService.filter_status(status, specimen_identifications)
    specimen_identifications = specimen_identifications.page(page_number).per(per_page)
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
    spid_ditributions = []
    spid_statuses = []
    spids = []
    ActiveRecord::Base.transaction do
      sin_to_distribute.each do |sin|
        spid_ditributions << {
          specimen_identification_id: sin.id,
          site_id: site.id
        }
        spid_statuses << {
          csig_status_id: csig_status.id,
          specimen_identification_id: sin.id,
          site_name: site.name
        }
        spids << sin.id
      end
      sin_to_distribute.update_all(distributed: true)
      SpecimenIdentificationDistribution.import(spid_ditributions)
      SpecimenIdentificationStatus.import(spid_statuses)
    end
    SpecimenIdentification.where(id: spids)
  end

  # Get distributed specimen id's with grouped by facility
  def self.distributions(per_page: 25, page_number: 1, query: nil)
    @distributions = SpecimenIdentificationDistribution
      .joins(:site, :specimen_identification)
      .select('spid_distributions.site_id, sites.name as site_name, specimen_identifications.sin')

    @distributions = CsigUtilityService.search_site_name(query, @distributions)
    @distributions = @distributions.page(page_number).per(per_page)

    formatted_data = @distributions.group_by { |item| [item.site_id, item.site_name] }.map do |(site_id, site_name), items|
      {
        site_name: site_name,
        site_id: site_id,
        specimens_id: items.map do |item|
        {
          sin: item.sin,
          used: true
        }
        end
      }
    end
    {
      data: @distributions,
      metadata: CsigUtilityService.page_metadata(@distributions)
    }
  end

  def self.distributions_by_facility(facility_name, from: nil, to: nil)
    distributions = SpecimenIdentificationDistribution
      .joins(:site, :specimen_identification)
      .where(sites: { name: facility_name })
      .where(updated_at: from..to)
      .select('spid_distributions.site_id, sites.name as site_name, specimen_identifications.sin')
    formatted_data = {}
    formatted_data[:distributions] = distributions.group_by { |item| [item.site_id, item.site_name] }.map do |(site_id, site_name), items|
      {
        site_name: site_name,
        site_id: site_id,
        generated_from: from,
        generated_to: to,
        specimens_id: items.map { |item| { sin: item.sin } }
      }
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
