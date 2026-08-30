# frozen_string_literal: true

module Dictionary
  # One dictionary entry as it travels between nodes.
  #
  # Everything is addressed by national code. Auto-increment ids never cross the
  # wire: they mean nothing on the other side and would silently point at the
  # wrong record after a re-seed.
  class Serializer
    def self.call(entity_type, record)
      new(entity_type, record).as_json
    end

    def initialize(entity_type, record)
      @entity_type = entity_type.to_s
      @record = record
    end

    def as_json
      base.merge(extras).merge(links)
    end

    private

    def base
      {
        entity: @entity_type,
        revision: @record.revision,
        uuid: @record.uuid,
        national_code: @record.national_code,
        status: @record.status,
        name: @record.name,
        short_name: @record.short_name,
        description: @record.description,
        loinc_code: @record.loinc_code,
        moh_code: @record.moh_code,
        deleted_at: @record.deleted_at&.iso8601
      }
    end

    def extras
      case @entity_type
      when "indicators" then indicator_extras
      when "test_types" then test_type_extras
      when "labs" then lab_extras
      when "facilities" then facility_extras
      else {}
      end
    end

    # Which unit the laboratory belongs to, and what its own LIS calls it. The
    # unit's district and province are not repeated here: they travel on the
    # facility entry, and a node that has this one has that one too.
    #
    # `source_code` goes out because it is how the node that registered the
    # laboratory recognises the capital's answer as its own.
    def lab_extras
      {
        facility_code: @record.facility_code,
        source_code: @record.source_code,
        phone: @record.phone
      }
    end

    # Where the unit is. A node that receives this can address a referral to any
    # laboratory in it without being told anything else.
    def facility_extras
      {
        district: @record.district,
        province: @record.province,
        phone: @record.phone
      }
    end

    def indicator_extras
      {
        unit: @record.unit,
        value_type: @record.value_type,
        ranges: @record.indicator_ranges.map { |range| range_json(range) }
      }
    end

    # Decimals travel as strings. A reference interval read back as a float and
    # written again drifts, and a drifting interval changes how a result reads.
    def range_json(range)
      {
        age_min: range.age_min,
        age_max: range.age_max,
        sex: range.sex,
        range_lower: range.range_lower&.to_s("F"),
        range_upper: range.range_upper&.to_s("F"),
        interpretation: range.interpretation,
        value: range.value
      }
    end

    def test_type_extras
      {
        department: @record.department && { national_code: @record.department.national_code },
        target_tat: @record.target_tat,
        performed_on_sex: @record.performed_on_sex
      }
    end

    def links
      Dictionary.links_for(@entity_type).to_h do |link|
        codes = @record.public_send(link.name).map(&:national_code)
        [ link.name, codes.sort.map { |code| { national_code: code } } ]
      end
    end
  end
end
