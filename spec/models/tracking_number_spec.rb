# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrackingNumber do
  # Sequence.next! takes a lock it holds until commit, so a number may only be
  # allocated inside a transaction.
  def generate(facility_code: "HCM", at: Time.current)
    described_class.generate(facility_code: facility_code, at: at)
  end

  it "reads MZ, the collecting facility, the day, and that day's sequence" do
    at = Time.zone.local(2026, 8, 17, 9, 30)

    expect(generate(at: at)).to eq("MZ-HCM-26229-0001")
    expect(generate(at: at)).to eq("MZ-HCM-26229-0002")
  end

  it "starts again the next day" do
    generate(at: Time.zone.local(2026, 8, 17))

    expect(generate(at: Time.zone.local(2026, 8, 18))).to eq("MZ-HCM-26230-0001")
  end

  it "counts per facility, so one busy laboratory does not push another's numbers along" do
    expect(generate(facility_code: "HCM", at: Time.zone.local(2026, 8, 17))).to end_with("-0001")
    expect(generate(facility_code: "XAI", at: Time.zone.local(2026, 8, 17))).to eq("MZ-XAI-26229-0001")
  end

  it "reads the facility code the way it will be printed" do
    expect(generate(facility_code: " hcm ")).to start_with("MZ-HCM-")
  end

  it "refuses to invent a number for a sample with no facility" do
    expect { generate(facility_code: nil) }.to raise_error(ArgumentError, /facility code/)
  end

  it "recognises its own format and nothing else" do
    expect(described_class.matches?("MZ-HCM-26229-0417")).to be(true)
    expect(described_class.matches?("MZ-HCM-LAB-26229-0417")).to be(true)
    expect(described_class.matches?("HCM-26229-0417")).to be(false)
    expect(described_class.matches?("MZ-HCM-26229")).to be(false)
    expect(described_class.matches?("")).to be(false)
  end

  # The property the number exists for. These need real concurrent connections,
  # so they run outside the surrounding test transaction and clean up after
  # themselves — the same arrangement as the dictionary cursor spec.
  describe "under concurrency" do
    self.use_transactional_tests = false

    after do
      StatusEvent.delete_all
      Order.delete_all
      Patient.delete_all
      SpecimenType.delete_all

      # The day's counters are this example's rubbish and go; the seeded ones are
      # the application's and only get rewound, or a spec that runs after this one
      # finds them missing.
      Sequence.where("name LIKE 'tracking:%'").delete_all
      Sequence.update_all(value: 0)
    end

    def in_new_connection(&block)
      ActiveRecord::Base.connection_pool.with_connection(&block)
    end

    # The current system reads the last row and adds one, and two registrations
    # that overlap then receive the same number. Registering twelve samples at one
    # facility on one day, from three connections at once, is the case that breaks
    # it — including the first of the day, when the counter itself does not exist
    # yet and has to be created by whichever registration gets there first.
    it "never hands the same number to two samples registered at once" do
      patient = create(:patient)
      specimen_type = create(:specimen_type)

      threads = Array.new(3) do
        Thread.new do
          in_new_connection do
            Array.new(4) do
              Order.create!(
                patient: patient,
                specimen_type: specimen_type,
                sending_facility_code: "HCM",
                receiving_lab_code: "HCM-LAB",
                priority: "routine"
              ).tracking_number
            end
          end
        end
      end

      numbers = threads.flat_map(&:value)

      expect(numbers.uniq.length).to eq(12)
      expect(numbers).to all(match(TrackingNumber::FORMAT))
      expect(Order.count).to eq(12)

      # Twelve samples on one day at one facility are numbered 1 to 12, with
      # nothing skipped: the sequence is what the day's register is read from.
      expect(numbers.map { |number| number.split("-").last.to_i }.sort).to eq((1..12).to_a)
    end

    # Uniqueness is the index's job, not the application's. If the counter were
    # ever bypassed, the database must still refuse the duplicate rather than
    # storing two samples that cannot be told apart.
    it "is refused by the database even when the counter is bypassed" do
      order = create(:order)

      expect { create(:order, tracking_number: order.tracking_number) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
