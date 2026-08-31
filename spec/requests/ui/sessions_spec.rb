# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessões da interface", type: :request do
  describe "entrar" do
    it "aceita as credenciais correctas e leva ao painel" do
      user = create(:user, email: "ana@hcm.gov.mz", password: "palavra-passe-boa")

      post session_path, params: { session: { email: "ana@hcm.gov.mz", password: "palavra-passe-boa" } }

      expect(response).to redirect_to(root_path)
      expect(user.sessions.count).to eq(1)
      expect(user.reload.last_signed_in_at).to be_present
    end

    it "aceita o endereço escrito com maiúsculas e espaços" do
      create(:user, email: "ana@hcm.gov.mz")

      post session_path, params: { session: { email: "  Ana@HCM.gov.MZ ", password: "palavra-passe-boa" } }

      expect(response).to redirect_to(root_path)
    end

    it "recusa a palavra-passe errada sem dizer que o endereço existe" do
      create(:user, email: "ana@hcm.gov.mz")

      post session_path, params: { session: { email: "ana@hcm.gov.mz", password: "errada" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Endereço ou palavra-passe incorrectos")
      expect(Session.count).to be_zero
    end

    it "dá exactamente a mesma resposta a um endereço que não existe" do
      create(:user, email: "ana@hcm.gov.mz")

      post session_path, params: { session: { email: "ninguem@hcm.gov.mz", password: "palavra-passe-boa" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Endereço ou palavra-passe incorrectos")
    end

    it "recusa uma conta desactivada" do
      create(:user, :disabled, email: "saiu@hcm.gov.mz")

      post session_path, params: { session: { email: "saiu@hcm.gov.mz", password: "palavra-passe-boa" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Session.count).to be_zero
    end

    it "leva ao ecrã que a pessoa pediu antes de lhe ser exigida a sessão" do
      user = create(:user)

      get root_path
      expect(response).to redirect_to(new_session_path)

      sign_in(user)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "sair" do
    it "termina a sessão e apaga a linha" do
      user = create(:user)
      sign_in(user)

      delete session_path

      expect(response).to redirect_to(new_session_path)
      expect(user.sessions.count).to be_zero

      get root_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "a sessão em si" do
    it "expira depois do período de inactividade" do
      user = create(:user)
      sign_in(user)

      get root_path
      expect(response).to have_http_status(:ok)

      travel(Session::IDLE_TIMEOUT + 1.minute) do
        get root_path

        expect(response).to redirect_to(new_session_path)
        expect(user.sessions.count).to be_zero
      end
    end

    it "deixa de valer assim que a conta é desactivada" do
      user = create(:user)
      sign_in(user)

      user.update!(active: false)

      get root_path
      expect(response).to redirect_to(new_session_path)
      expect(user.sessions.count).to be_zero
    end

    it "ignora um cookie que aponta para uma sessão que já não existe" do
      user = create(:user)
      sign_in(user)
      Session.delete_all

      get root_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "quem já entrou" do
    it "não volta a ver o formulário" do
      sign_in_as

      get new_session_path

      expect(response).to redirect_to(root_path)
    end
  end
end
