# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Fila de sincronização", mode: :local, type: :request do
  before { sign_in_as }

  def failing_event
    create(:order)
    OutboxEvent.pending.first.tap { |event| event.mark_failed!("500 do nó nacional") }
  end

  it "mostra o que está por enviar e o erro que o está a travar" do
    event = failing_event

    get sync_queue_path, params: { filter: "failing" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(event.type)
    expect(response.body).to include("500 do nó nacional")
  end

  it "liga cada evento à amostra de que fala" do
    create(:order)
    tracking_number = Order.sole.tracking_number

    get sync_queue_path

    expect(response.body).to include(tracking_number)
  end

  it "recoloca um evento na fila, limpando o intervalo de espera" do
    event = failing_event
    expect(event.next_attempt_at).to be_present

    post retry_sync_event_path(event)

    expect(response).to redirect_to(sync_queue_path)
    expect(event.reload.next_attempt_at).to be_nil
    expect(event.last_error).to be_nil
  end

  it "recoloca todos os que falharam de uma vez" do
    failing_event
    failing_event

    post retry_all_sync_events_path

    expect(OutboxEvent.pending.where.not(next_attempt_at: nil)).to be_empty
  end

  it "não apaga nada — um evento entregue continua a ser a prova de que seguiu" do
    event = failing_event
    event.mark_delivered!

    post retry_all_sync_events_path

    expect(OutboxEvent.exists?(event.id)).to be(true)
    expect(event.reload).to be_delivered
  end

  it "pede um envio, para que o botão faça alguma coisa agora e não à próxima ronda" do
    event = failing_event

    allow(SyncPushJob).to receive(:perform_later)

    post retry_sync_event_path(event)

    expect(SyncPushJob).to have_received(:perform_later)
  end

  it "aceita o reprocessamento mesmo que não haja quem o vá buscar" do
    event = failing_event
    allow(SyncPushJob).to receive(:perform_later).and_raise(Redis::CannotConnectError)

    post retry_sync_event_path(event)

    expect(response).to redirect_to(sync_queue_path)
    expect(event.reload.next_attempt_at).to be_nil
  end
end
