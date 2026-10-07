# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderService do
  let(:vl_type_id) { test_type_id('HIV Viral Load') }
  let(:other_type_id) { test_type_id('FBC') }
  let(:voided_status_id) { test_status_id('voided') }
  let(:pending_status_id) { test_status_id('pending') }

  def test_status_id(name)
    TestStatus.find_by(name:)&.id || begin
      TestStatus.insert_all!([{ name:, test_phase_id: 1, created_at: Time.now, updated_at: Time.now }])
      TestStatus.find_by(name:).id
    end
  end

  def test_type_id(name)
    TestType.find_by(name:)&.id || begin
      TestType.insert_all!([{ name:, created_at: Time.now, updated_at: Time.now }])
      TestType.find_by(name:).id
    end
  end

  def add_order(facility, test_type_id, date_created: Time.now, test_status_id: pending_status_id)
    tracking_number = "X#{SecureRandom.hex(4)}"
    Speciman.insert_all!([{ specimen_type_id: 1, specimen_status_id: 1, ward_id: 1, tracking_number:, priority: 'Routine',
                            target_lab: 'CHSU', sending_facility: facility, requested_by: 'Dr', date_created: }])
    specimen_id = Speciman.find_by(tracking_number:).id
    Test.insert_all!([{ specimen_id:, test_type_id:, test_status_id:, created_at: Time.now, updated_at: Time.now }])
  end

  describe '.nlims_orders_count_by_facility' do
    it 'matches nlims_local_orders counts for each facility' do
      vl = vl_type_id
      add_order('Site A', vl)
      add_order('Site A', vl)
      add_order('Site A', other_type_id)
      add_order('Site A', vl, test_status_id: voided_status_id)
      add_order('Site A', vl, date_created: 5.days.ago)
      add_order('Site B', vl)
      concept = { name: 'HIV Viral Load', id: 856 }
      start_date = Date.today - 1.day

      counts = described_class.nlims_orders_count_by_facility(start_date, Date.today, concept, ['Site A', 'Site B', 'Site C'])

      expect(counts).to eq('Site A' => 2, 'Site B' => 1)
      %w[Site\ A Site\ B].each do |facility|
        expected = described_class.nlims_local_orders(start_date, Date.today, concept, sending_facility: facility).count
        expect(counts[facility]).to eq(expected)
      end
    end
  end

  describe '.nlims_local_orders' do
    it 'treats the concept name as data, not SQL' do
      concept = { name: "x' OR '1'='1", id: 1 }
      expect { described_class.nlims_local_orders(Date.today, Date.today, concept).to_a }.not_to raise_error
    end
  end
end
