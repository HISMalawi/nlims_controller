# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ecrã de nós", mode: :national, type: :request do
  before { sign_in_as }

  it "mostra quem falou e há quanto tempo" do
    Node.heard_from!("HCM", version: "2.0.0", dictionary_cursor: 10)

    get nodes_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("HCM")
    expect(response.body).to include("2.0.0")
  end

  it "destaca um nó que deixou de dar notícias" do
    silent = Node.heard_from!("HPM")
    silent.update_column(:last_seen_at, 2.days.ago)

    get nodes_path

    expect(response.body).to include("Sem contacto")
  end

  it "diz quantas revisões do dicionário um nó tem em atraso" do
    create(:test_type)
    Node.heard_from!("HCM", dictionary_cursor: 0)

    get nodes_path

    expect(Dictionary.cursor).to be_positive
    expect(response.body).to include("revisões atrás")
  end

  it "põe à frente os nós que nunca apareceram e os mais antigos" do
    Node.heard_from!("RECENTE")
    old = Node.heard_from!("ANTIGO")
    old.update_column(:last_seen_at, 3.days.ago)

    get nodes_path

    expect(response.body.index("ANTIGO")).to be < response.body.index("RECENTE")
  end
end
