# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ecrã de pedidos", type: :request do
  before { sign_in_as }

  describe "pesquisa" do
    it "vai directamente à amostra quando lhe dão um tracking number completo" do
      order = create(:order)

      get orders_path, params: { q: order.tracking_number }

      expect(response).to redirect_to(order_path(order.tracking_number))
    end

    it "aceita o tracking number escrito em minúsculas" do
      order = create(:order)

      get orders_path, params: { q: order.tracking_number.downcase }

      expect(response).to redirect_to(order_path(order.tracking_number))
    end

    it "encontra pelo NID do doente" do
      patient = create(:patient, :identified, name: "Ana Machava")
      order = create(:order, patient: patient)
      create(:order)

      get orders_path, params: { q: patient.national_id }

      expect(response.body).to include(order.tracking_number)
      expect(response.body).to include("Ana Machava")
    end

    it "encontra pelo início do nome do doente" do
      order = create(:order, patient: create(:patient, name: "Ana Machava"))
      other = create(:order, patient: create(:patient, name: "Bento Cossa"))

      get orders_path, params: { q: "Ana" }

      expect(response.body).to include(order.tracking_number)
      expect(response.body).not_to include(other.tracking_number)
    end

    it "não encontra nada com um tracking number quase certo" do
      order = create(:order)
      near_miss = order.tracking_number.sub(/\d\z/) { |digit| ((digit.to_i + 1) % 10).to_s }

      get orders_path, params: { q: near_miss }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(order.tracking_number)
    end

    it "filtra por estado" do
      done = create(:order)
      done.transition_to!(Order::ACCEPTED)
      waiting = create(:order)

      get orders_path, params: { status: Order::REQUESTED }

      expect(response.body).to include(waiting.tracking_number)
      expect(response.body).not_to include(done.tracking_number)
    end

    it "filtra por unidade e por período" do
      here = create(:order, sending_facility_code: "HCM")
      elsewhere = create(:order, sending_facility_code: "HPM")

      get orders_path, params: { facility: "hcm", from: Date.current.to_s, to: Date.current.to_s }

      expect(response.body).to include(here.tracking_number)
      expect(response.body).not_to include(elsewhere.tracking_number)
    end
  end

  describe "detalhe" do
    it "mostra o histórico completo, incluindo o dos testes" do
      order = create(:order)
      order_test = create(:order_test, order: order)
      order.transition_to!(Order::ACCEPTED, actor: "Ana Machava", reason: "reclamado por HCM-LAB")
      order_test.transition_to!(OrderTest::IN_PROGRESS, actor: "Bento Cossa")

      get order_path(order.tracking_number)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(order.tracking_number)
      expect(response.body).to include("Ana Machava")
      expect(response.body).to include("Bento Cossa")
      expect(response.body).to include("reclamado por HCM-LAB")
      expect(response.body).to include(order_test.test_type.name)
    end

    it "mostra os resultados registados" do
      result = create(:test_result, value: "12.4", unit: "g/dL")
      order = result.order_test.order

      get order_path(order.tracking_number)

      expect(response.body).to include("12.4")
      expect(response.body).to include("g/dL")
      expect(response.body).to include(result.indicator.name)
    end

    it "mostra o motivo quando a amostra foi rejeitada" do
      order = create(:order)
      reason = create(:rejection_reason, name: "Amostra hemolisada")
      order.transition_to!(Order::ACCEPTED)
      order.reject!(reason: reason)

      get order_path(order.tracking_number)

      expect(response.body).to include("Amostra hemolisada")
    end

    # Um termo guardado como chegou é legítimo enquanto o catálogo nacional
    # não estiver consolidado, mas não é o mesmo que um termo catalogado — e
    # quem está a olhar para o ecrã é quem pode tratar da diferença.
    it "marca o exame que ficou fora do catálogo" do
      order = create(:order)
      order_test = order.order_tests.new(status_actor: "spec")
      order_test.test_type_reference = { national_code: "MOZ-TT-9999", name: "Ferritina" }
      order_test.save!

      get order_path(order.tracking_number)

      expect(response.body).to include("Ferritina")
      expect(response.body).to include("MOZ-TT-9999")
      expect(response.body).to include("fora do catálogo")
    end

    it "não marca o exame que o catálogo conhece" do
      order = create(:order)
      create(:order_test, order: order, test_type: create(:test_type, name: "Hemograma"))

      get order_path(order.tracking_number)

      expect(response.body).to include("Hemograma")
      expect(response.body).not_to include("fora do catálogo")
    end

    it "devolve o operador à lista quando o tracking number não existe" do
      get order_path("MZ-HCM-26229-9999")

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end

  it "exige sessão iniciada" do
    delete session_path

    get orders_path

    expect(response).to redirect_to(new_session_path)
  end
end
