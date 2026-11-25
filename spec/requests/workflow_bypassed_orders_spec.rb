# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Workflow bypassed orders', type: :request do
  let(:payload) do
    {
      tracking_number: 'XKCH2600001',
      order_date: '2026-10-12T08:30:00+02:00',
      specimen_type: 'Plasma',
      test_type: 'Viral Load',
      ordering_facility: { site_code_number: '1501', name: 'Name sent by the caller' },
      ordered_by: 'Dr Banda',
      lab: 'Kamuzu Central Hospital Lab',
      arv_number: '22-2121'
    }
  end
  let(:review_dir) { Pathname.new(Dir.mktmpdir) }
  let(:review_csv) { review_dir.join('bypassed_orders_for_review.csv') }

  before do
    allow(UserService).to receive(:check_token).and_return(true)
    allow(WorkflowBypassedOrders::ReviewLog).to receive(:path).and_return(review_csv)
    Site.create!(name: 'Area 18 Urban Health Centre', district: 'Lilongwe', enabled: true, site_code_number: '1501')
    Site.create!(name: 'Chitipa District Hospital', district: 'chitipa', enabled: true, site_code_number: '0102')
    Site.create!(name: 'Ifumbo Health Centre', district: 'chitipa', enabled: false, site_code_number: '0103')
  end

  after { FileUtils.rm_rf(review_dir) }

  def post_order(params)
    post '/api/v2/workflow_bypassed_orders', params:, headers: { 'token' => 'test' }, as: :json
  end

  it 'logs the sample' do
    expect { post_order(payload) }.to change(WorkflowBypassedOrder, :count).by(1)

    expect(response).to have_http_status(:created)
    record = WorkflowBypassedOrder.find_by!(tracking_number: 'XKCH2600001')
    expect(record.ordered_at).to eq(Time.zone.parse('2026-10-12T08:30:00+02:00'))
    expect(record).to have_attributes(specimen_type: 'Plasma', test_type: 'Viral Load', ordered_by: 'Dr Banda',
                                      ordering_facility: 'Area 18 Urban Health Centre',
                                      receiving_lab: 'Kamuzu Central Hospital Lab', arv_number: '22-2121')
  end

  it 'saves the facility name held for the site code number, not the name that was sent' do
    post_order(payload)

    expect(WorkflowBypassedOrder.last.ordering_facility).to eq('Area 18 Urban Health Centre')
  end

  it 'does not need the facility name' do
    post_order(payload.merge(ordering_facility: { site_code_number: '1501' }))

    expect(response).to have_http_status(:created)
    expect(WorkflowBypassedOrder.last.ordering_facility).to eq('Area 18 Urban Health Centre')
  end

  it 'ignores spaces around the site code number' do
    post_order(payload.merge(ordering_facility: { site_code_number: ' 1501 ' }))

    expect(response).to have_http_status(:created)
  end

  it 'adds the leading zero to a 3 digit site code number' do
    post_order(payload.merge(ordering_facility: { site_code_number: '102' }))

    expect(response).to have_http_status(:created)
    expect(WorkflowBypassedOrder.last.ordering_facility).to eq('Chitipa District Hospital')
  end

  it 'only pads 3 digit site code numbers' do
    Site.create!(name: 'Two Digit Clinic', district: 'x', enabled: true, site_code_number: '0012')

    post_order(payload.merge(ordering_facility: { site_code_number: '12' }))

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['message']).to eq('site code number does not match any site in nlims')
  end

  it 'still understands a site code number sent as a JSON number' do
    post_order(payload.merge(ordering_facility: { site_code_number: 102 }))

    expect(response).to have_http_status(:created)
    expect(WorkflowBypassedOrder.last.ordering_facility).to eq('Chitipa District Hospital')
  end

  it 'uses the oldest enabled site when several share the site code number' do
    Site.create!(name: 'Moyale Barracks Health Centre', district: 'mzimba', enabled: true, site_code_number: '0701')
    Site.create!(name: 'Mzuzu Urban Health Centre', district: 'mzimba', enabled: true, site_code_number: '0701')

    post_order(payload.merge(ordering_facility: { site_code_number: '0701' }))

    expect(WorkflowBypassedOrder.last.ordering_facility).to eq('Moyale Barracks Health Centre')
  end

  it 'logs the sample without an ARV number' do
    expect { post_order(payload.except(:arv_number)) }.to change(WorkflowBypassedOrder, :count).by(1)
    expect(WorkflowBypassedOrder.last.arv_number).to be_nil

    post_order(payload.merge(tracking_number: 'XKCH2600002', arv_number: '  '))
    expect(WorkflowBypassedOrder.last.arv_number).to be_nil
  end

  describe 'a site code number that matches no site' do
    def review_rows
      CSV.parse(review_csv.read, headers: true)
    end

    it 'does not log the sample and says why' do
      expect { post_order(payload.merge(ordering_facility: { site_code_number: '9999' })) }
        .not_to change(WorkflowBypassedOrder, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => true, 'data' => {},
                                         'message' => 'site code number does not match any site in nlims')
    end

    it 'writes what was sent to the review CSV' do
      post_order(payload.merge(ordering_facility: { site_code_number: '9999', name: 'Unknown Clinic' }))

      expect(review_rows.headers).to eq(WorkflowBypassedOrders::ReviewLog::HEADERS)
      expect(review_rows.size).to eq(1)
      expect(review_rows.first.to_h).to include(
        'reason' => 'site code number does not match any site in nlims', 'tracking_number' => 'XKCH2600001',
        'order_date' => '2026-10-12T08:30:00+02:00', 'specimen_type' => 'Plasma', 'test_type' => 'Viral Load',
        'site_code_number' => '9999', 'facility_name' => 'Unknown Clinic', 'ordered_by' => 'Dr Banda',
        'lab' => 'Kamuzu Central Hospital Lab', 'arv_number' => '22-2121'
      )
      expect(review_rows.first['logged_at']).to be_present
      expect(review_rows.first['source_ip']).to be_present
    end

    it 'appends to the CSV and writes the header once' do
      post_order(payload.merge(ordering_facility: { site_code_number: '9999' }))
      post_order(payload.merge(tracking_number: 'XKCH2600002', ordering_facility: { site_code_number: '8888' }))

      expect(review_csv.read.lines.count { |line| line.start_with?('logged_at,') }).to eq(1)
      expect(review_rows.pluck('tracking_number')).to eq(%w[XKCH2600001 XKCH2600002])
    end

    it 'treats a disabled site as no match' do
      expect { post_order(payload.merge(ordering_facility: { site_code_number: '0103' })) }
        .not_to change(WorkflowBypassedOrder, :count)

      expect(response.parsed_body['message']).to eq('site code number does not match any site in nlims')
      expect(review_rows.size).to eq(1)
    end

    it 'keeps commas, quotes and line breaks intact and defuses spreadsheet formulas' do
      post_order(payload.merge(ordering_facility: { site_code_number: '9999', name: '=HYPERLINK("http://x")' },
                               ordered_by: "Dr \"B\", Banda\nNight shift"))

      expect(review_rows.first['facility_name']).to eq("'=HYPERLINK(\"http://x\")")
      expect(review_rows.first['ordered_by']).to eq("Dr \"B\", Banda\nNight shift")
    end

    it 'still answers when the review CSV cannot be written' do
      allow(WorkflowBypassedOrders::ReviewLog).to receive(:path).and_return(review_dir.join('missing', 'review.csv'))

      post_order(payload.merge(ordering_facility: { site_code_number: '9999' }))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['message']).to eq('site code number does not match any site in nlims')
    end

    it 'is skipped, not reviewed, when the order already exists in NLIMS' do
      allow(Speciman).to receive(:exists?).with(tracking_number: 'XKCH2600001').and_return(true)

      post_order(payload.merge(ordering_facility: { site_code_number: '9999' }))

      expect(response).to have_http_status(:ok)
      expect(review_csv).not_to exist
    end
  end

  it 'rejects a missing site code number' do
    [{ name: 'Area 18 Urban Health Centre' }, {}, nil, 'Area 18 Urban Health Centre', { site_code_number: ' ' }]
      .each do |facility|
      post_order(payload.merge(ordering_facility: facility))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['message']).to eq('facility site code number not provided')
    end
    post_order(payload.except(:ordering_facility))
    expect(response.parsed_body['message']).to eq('facility site code number not provided')
    expect(WorkflowBypassedOrder.count).to eq(0)
  end

  it 'skips when the order already exists in specimen' do
    allow(Speciman).to receive(:exists?).with(tracking_number: 'XKCH2600001').and_return(true)

    expect { post_order(payload) }.not_to change(WorkflowBypassedOrder, :count)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['message']).to match(/exists in nlims/)
  end

  it 'skips a tracking number that was already logged' do
    post_order(payload)

    expect { post_order(payload) }.not_to change(WorkflowBypassedOrder, :count)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['message']).to match(/already logged/)
  end

  it 'rejects a missing ordered by' do
  expect { post_order(payload.except(:ordered_by)) }
    .not_to change(WorkflowBypassedOrder, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['message']).to eq('person who placed the order not provided')
  end

  it 'rejects a missing lab' do
    expect { post_order(payload.except(:lab)) }
      .not_to change(WorkflowBypassedOrder, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['message']).to eq('lab that received the order not provided')
  end

  it 'rejects a missing required field' do
    expect { post_order(payload.except(:test_type)) }.not_to change(WorkflowBypassedOrder, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['message']).to eq('test type not provided')
  end

  it 'rejects an invalid order date' do
    post_order(payload.merge(order_date: 'not a date'))

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['message']).to match(/order date/)
  end

  describe 'GET /api/v2/workflow_bypassed_orders' do
    include ActiveSupport::Testing::TimeHelpers

    def log_order(tracking_number, order_date, **attrs)
      WorkflowBypassedOrder.create!({ tracking_number:, ordered_at: Time.zone.parse(order_date),
                                      specimen_type: 'Plasma', test_type: 'Viral Load',
                                      ordering_facility: 'Area 18 Urban Health Centre', ordered_by: 'Dr Banda',
                                      receiving_lab: 'Kamuzu Central Hospital Lab' }.merge(attrs))
    end

    def list_orders(params = {})
      get '/api/v2/workflow_bypassed_orders', params:, headers: { 'token' => 'test' }
      response.parsed_body
    end

    def tracking_numbers(body)
      body.dig('data', 'orders').pluck('tracking_number')
    end

    before do
      log_order('SEP30', '2026-09-30 23:59:59')
      log_order('OCT01', '2026-10-01 00:00:00')
      log_order('OCT15', '2026-10-15 09:00:00', specimen_type: 'Serum', test_type: 'CD4',
                                                ordering_facility: 'Kawale Health Centre', ordered_by: 'Dr Phiri',
                                                arv_number: '22-2121')
      log_order('OCT31', '2026-10-31 23:59:59', receiving_lab: 'Queen Elizabeth Central Hospital Lab')
      log_order('NOV01', '2026-11-01 00:00:00')
      travel_to Time.zone.local(2026, 10, 20, 12)
    end

    after { travel_back }

    it 'defaults to the current calendar month and reports the period' do
      body = list_orders

      expect(response).to have_http_status(:ok)
      expect(body['error']).to be(false)
      expect(body['data']['period']).to eq('start_date' => '2026-10-01', 'end_date' => '2026-10-31', 'days' => 31)
      expect(body['data']['total']).to eq(3)
      expect(tracking_numbers(body)).to eq(%w[OCT31 OCT15 OCT01])
    end

    it 'returns the order in the documented format' do
      order = list_orders(tracking_number: 'OCT15').dig('data', 'orders', 0)

      expect(order).to include('tracking_number' => 'OCT15', 'order_date' => '2026-10-15T09:00:00+02:00',
                               'specimen_type' => 'Serum', 'test_type' => 'CD4',
                               'ordering_facility' => 'Kawale Health Centre', 'ordered_by' => 'Dr Phiri',
                               'lab' => 'Kamuzu Central Hospital Lab', 'arv_number' => '22-2121')
      expect(order).to have_key('logged_at')
      expect(list_orders(tracking_number: 'OCT01').dig('data', 'orders', 0)).to include('arv_number' => nil)
    end

    it 'includes the whole of the start and end dates' do
      body = list_orders(start_date: '2026-09-30', end_date: '2026-10-01')

      expect(tracking_numbers(body)).to eq(%w[OCT01 SEP30])
      expect(body['data']['period']).to include('start_date' => '2026-09-30', 'end_date' => '2026-10-01', 'days' => 2)
    end

    it 'fills in the end date when only the start date is given' do
      body = list_orders(start_date: '2026-10-15')

      expect(body['data']['period']).to include('start_date' => '2026-10-15', 'end_date' => '2026-11-14')
      expect(tracking_numbers(body)).to eq(%w[NOV01 OCT31 OCT15])
    end

    it 'fills in the start date when only the end date is given' do
      body = list_orders(end_date: '2026-10-15')

      expect(body['data']['period']).to include('start_date' => '2026-09-15', 'end_date' => '2026-10-15')
      expect(tracking_numbers(body)).to eq(%w[OCT15 OCT01 SEP30])
    end

    it 'filters by any combination of parameters' do
      expect(tracking_numbers(list_orders(specimen_type: 'Serum'))).to eq(%w[OCT15])
      expect(tracking_numbers(list_orders(arv_number: '22-2121'))).to eq(%w[OCT15])
      expect(tracking_numbers(list_orders(test_type: 'Viral Load', lab: 'Kamuzu Central Hospital Lab')))
        .to eq(%w[OCT01])
      expect(tracking_numbers(list_orders(ordering_facility: 'Kawale Health Centre', ordered_by: 'Dr Phiri',
                                          start_date: '2026-10-01', end_date: '2026-10-31'))).to eq(%w[OCT15])
      expect(tracking_numbers(list_orders(ordered_by: 'Dr Phiri', specimen_type: 'Plasma'))).to be_empty
    end

    it 'echoes the filters that were applied' do
      body = list_orders(specimen_type: 'Serum', lab: ' ')

      expect(body['data']['filters']).to eq('specimen_type' => 'Serum')
    end

    it 'returns an empty list when nothing matches' do
      body = list_orders(tracking_number: 'NOPE')

      expect(response).to have_http_status(:ok)
      expect(body['data']).to include('total' => 0, 'orders' => [])
    end

    it 'accepts a period of exactly one month' do
      list_orders(start_date: '2026-10-01', end_date: '2026-10-31')

      expect(response).to have_http_status(:ok)
    end

    it 'rejects a period longer than one month' do
      body = list_orders(start_date: '2026-10-01', end_date: '2026-11-01')

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['message']).to match(/longer than one month/)
    end

    it 'rejects an end date before the start date' do
      body = list_orders(start_date: '2026-10-10', end_date: '2026-10-01')

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['message']).to eq('end_date cannot be before start_date')
    end

    it 'rejects invalid dates' do
      expect(list_orders(start_date: 'garbage')['message']).to eq('start_date is not a valid date, use YYYY-MM-DD')
      expect(list_orders(end_date: '2026-13-45')['message']).to eq('end_date is not a valid date, use YYYY-MM-DD')
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
