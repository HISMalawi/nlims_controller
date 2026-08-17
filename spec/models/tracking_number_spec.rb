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

  # The property the number exists for. This needs real concurrent connections,
  # so it runs outside the surrounding test transaction and cleans up after
  # itself — the same arrangement as the dictionary cursor spec.
  describe "under concurrency" do
    self.use_transactional_tests = false

    after do
      Sequence.where("name LIKE 'tracking:%'").delete_all
    end

    # Three connections asking for the same day's numbers at once, starting
    # from a counter that does not exist yet: the first sample of the day is
    # exactly when several registrations collide, and it is the case the old
    # read-the-last-row generator gets wrong.
    it "never hands the same number to two callers" do
      threads = Array.new(3) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Array.new(4) { Sequence.transaction { generate } }
          end
        end
      end

      numbers = threads.flat_map(&:value)

      expect(numbers.uniq.length).to eq(12)
      expect(numbers.map { |number| number.split("-").last.to_i }.sort).to eq((1..12).to_a)
    end
  end
end
