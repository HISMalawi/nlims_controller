# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Workflow bypassed orders', type: :request do
  let(:payload) do
    {
      tracking_number: 'XKCH2600001',
      order_date: '2026-10-12T08:30:00+02:00',
      specimen_type: 'Plasma',
      test_type: 'Viral Load',
      ordering_facility: 'Area 18 Urban Health Centre',
      ordered_by: 'Dr Banda',
      lab: 'Kamuzu Central Hospital Lab'
    }
  end

  before { allow(UserService).to receive(:check_token).and_return(true) }

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
                                      receiving_lab: 'Kamuzu Central Hospital Lab')
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
end
