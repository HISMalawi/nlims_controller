# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowBypassedOrders::SiteLookup do
  describe '.normalize' do
    it 'adds the leading zero to a 3 digit code' do
      expect(described_class.normalize('102')).to eq('0102')
    end

    it 'trims spaces and leaves other codes alone' do
      expect(described_class.normalize(' 1501 ')).to eq('1501')
      expect(described_class.normalize('12')).to eq('12')
      expect(described_class.normalize('00102')).to eq('00102')
      expect(described_class.normalize('AB1')).to eq('AB1')
      expect(described_class.normalize(nil)).to eq('')
    end

    it 'accepts a number' do
      expect(described_class.normalize(102)).to eq('0102')
    end
  end

  describe '.facility_name' do
    before do
      Site.create!(name: 'Chitipa District Hospital', district: 'chitipa', enabled: true, site_code_number: '0102')
      Site.create!(name: 'Ifumbo Health Centre', district: 'chitipa', enabled: false, site_code_number: '0103')
      Site.create!(name: 'No Name Yet', district: 'x', enabled: true, site_code_number: '0104').update_column(:name, '')
    end

    it 'returns the name of the enabled site, padding a 3 digit code' do
      expect(described_class.facility_name('0102')).to eq('Chitipa District Hospital')
      expect(described_class.facility_name('102')).to eq('Chitipa District Hospital')
    end

    it 'returns nil for a disabled site, an unknown code, a blank code or a site without a name' do
      expect(described_class.facility_name('0103')).to be_nil
      expect(described_class.facility_name('9999')).to be_nil
      expect(described_class.facility_name('')).to be_nil
      expect(described_class.facility_name('0104')).to be_nil
    end

    it 'uses the oldest enabled site when several share the code, and warns' do
      Site.create!(name: 'First', district: 'a', enabled: true, site_code_number: '0701')
      Site.create!(name: 'Second', district: 'b', enabled: true, site_code_number: '0701')
      allow(Rails.logger).to receive(:warn)

      expect(described_class.facility_name('0701')).to eq('First')
      expect(Rails.logger).to have_received(:warn).with(/0701/)
    end
  end
end
