# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Painel do nó", type: :request do
  before { sign_in_as }

  it "abre" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(SislabSync.node_code)
  end

  describe "num nó local", mode: :local do
    it "diz que ainda nunca falou com o nó nacional" do
      get root_path

      expect(response.body).to include("ainda nunca comunicou")
    end

    it "conta o que está por enviar e mostra a idade do mais antigo" do
      travel_to(3.hours.ago) { create(:order) }

      get root_path

      expect(OutboxEvent.pending.count).to be_positive
      expect(response.body).to include(OutboxEvent.pending.count.to_s)
      expect(response.body).to include("horas")
    end

    it "mostra o erro que impede a sincronização" do
      SyncCursor.for(SyncCursor::HEARTBEAT).record_failure!("Connection refused para o nó nacional")

      get root_path

      expect(response.body).to include("não está a conseguir comunicar")
      expect(response.body).to include("Connection refused para o nó nacional")
    end

    it "diz que está a comunicar depois de um heartbeat bem sucedido" do
      SyncCursor.for(SyncCursor::HEARTBEAT).mark_synced!

      get root_path

      expect(response.body).to include("está a comunicar")
    end
  end

  describe "no nó nacional", mode: :national do
    it "conta os nós que deixaram de dar notícias" do
      Node.heard_from!("HCM")
      silent = Node.heard_from!("HPM")
      silent.update_column(:last_seen_at, 2.days.ago)

      get root_path

      expect(response.body).to include("Nós sem contacto")
      expect(NodeStatus.call.stale_nodes).to eq(1)
    end

    it "conta os rascunhos do dicionário por promover" do
      create_list(:test_type, 2, :draft)

      get root_path

      expect(response.body).to include("Rascunhos por promover")
      expect(NodeStatus.call.dictionary_drafts).to eq(2)
    end
  end
end
