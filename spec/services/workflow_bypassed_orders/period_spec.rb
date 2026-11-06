# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowBypassedOrders::Period do
  let(:today) { Date.new(2026, 11, 6) }

  def period(start_value = nil, end_value = nil)
    described_class.new(start_value, end_value, today:)
  end

  it 'is the current calendar month when no dates are given' do
    expect(period.to_h).to eq(start_date: Date.new(2026, 11, 1), end_date: Date.new(2026, 11, 30), days: 30)
  end

  it 'counts a month forward from a start date and back from an end date' do
    expect(period('2026-10-15').to_h).to include(start_date: Date.new(2026, 10, 15), end_date: Date.new(2026, 11, 14))
    expect(period(nil, '2026-10-15').to_h).to include(start_date: Date.new(2026, 9, 15),
                                                      end_date: Date.new(2026, 10, 15))
  end

  it 'keeps both dates when they are given' do
    expect(period('2026-10-01', '2026-10-31').to_h).to eq(start_date: Date.new(2026, 10, 1),
                                                          end_date: Date.new(2026, 10, 31), days: 31)
  end

  it 'covers the whole of the first and last day' do
    range = period('2026-10-01', '2026-10-02').range

    expect(range.begin).to eq(Time.zone.local(2026, 10, 1, 0, 0, 0))
    expect(range.end.to_i).to eq(Time.zone.local(2026, 10, 2).end_of_day.to_i)
  end

  it 'accepts a date time by using its date' do
    expect(period('2026-10-01T08:30:00+02:00', '2026-10-05 10:00').to_h).to include(start_date: Date.new(2026, 10, 1),
                                                                                    end_date: Date.new(2026, 10, 5))
  end

  it 'explains why a period is not valid' do
    expect(period('garbage').error).to eq('start_date is not a valid date, use YYYY-MM-DD')
    expect(period(nil, '2026-13-45').error).to eq('end_date is not a valid date, use YYYY-MM-DD')
    expect(period('2026-10-10', '2026-10-01').error).to eq('end_date cannot be before start_date')
    expect(period('2026-10-01', '2026-11-01').error).to eq('the period cannot be longer than one month (31 days)')
    expect(period('2026-10-01', '2026-10-31')).to be_valid
  end
end
