# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dicionário na interface", type: :request do
  describe "ler" do
    before { sign_in_as }

    it "lista as entidades com o que cada uma tem" do
      create(:test_type, name: "Hemoglobina")
      create(:test_type, :draft, name: "Por publicar")

      get dictionary_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Testes")
    end

    it "procura pelo nome e pelo código" do
      wanted = create(:test_type, name: "Hemoglobina")
      other = create(:test_type, name: "Glicemia")

      get dictionary_entity_path("test_types"), params: { q: "Hemo" }
      expect(response.body).to include("Hemoglobina")
      expect(response.body).not_to include("Glicemia")

      get dictionary_entity_path("test_types"), params: { q: wanted.national_code }
      expect(response.body).to include(wanted.national_code)
      expect(response.body).not_to include(other.national_code)
    end

    it "diz que cobertura LOINC existe, que é a razão de este ecrã existir" do
      create(:test_type, loinc_code: "718-7")
      create(:test_type, loinc_code: nil)

      get dictionary_entity_path("test_types")

      expect(response.body).to include("Cobertura LOINC")
      expect(response.body).to include("50%")
      expect(response.body).to include("sem LOINC")
    end

    it "não mede cobertura onde um código LOINC nunca significaria nada" do
      create(:department)

      get dictionary_entity_path("departments")

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Cobertura LOINC")
    end

    it "mostra a cobertura de todo o dicionário logo à entrada" do
      create(:test_type, loinc_code: "718-7")
      create(:test_type, loinc_code: nil)
      create(:department, loinc_code: nil)

      get dictionary_path

      expect(response.body).to include("Cobertura LOINC")
      expect(response.body).to include("1 de 2 entradas curáveis")
    end

    # O registo de laboratórios anda no dicionário, e por isso ganha o ecrã de
    # graça: é o que o nó nacional mantém e o que os nós locais consultam para
    # saber para onde podem referir uma amostra.
    it "lista o registo de laboratórios como mais uma entidade" do
      create(:lab, name: "Laboratório Central de Maputo", facility_name: "Hospital Central de Maputo")

      get dictionary_path

      expect(response.body).to include("Laboratórios")

      get dictionary_entity_path("labs")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Laboratório Central de Maputo")
    end

    it "não conhece uma entidade que não existe" do
      get dictionary_entity_path("bananas")

      expect(response).to redirect_to(root_path)
    end
  end

  describe "escrever", mode: :national do
    it "não é para um operador comum" do
      sign_in_as
      entry = create(:test_type, :draft)

      get edit_dictionary_entry_path("test_types", entry.national_code)

      expect(response).to redirect_to(root_path)
    end

    describe "sendo administrador" do
      before { sign_in_as :admin }

      it "cria uma entrada como rascunho, com código nacional atribuído" do
        post dictionary_entries_path("test_types"), params: { entry: { name: "Carga viral" } }

        entry = TestType.find_by(name: "Carga viral")
        expect(entry).to be_draft
        expect(entry.national_code).to match(/\AMOZ-TT-\d{4}\z/)
      end

      it "cura um código LOINC e faz a entrada avançar de revisão" do
        entry = create(:test_type, name: "Hemoglobina", loinc_code: nil)
        before_revision = entry.revision

        patch dictionary_entry_path("test_types", entry.national_code),
              params: { entry: { name: "Hemoglobina", loinc_code: "718-7" } }

        expect(entry.reload.loinc_code).to eq("718-7")
        expect(entry.revision).to be > before_revision
      end

      it "activa um rascunho e assina quem o fez" do
        user = create(:user, :admin, name: "Ana Machava", email: "ana@hcm.gov.mz")
        sign_in(user)
        entry = create(:test_type, :draft)

        post activate_dictionary_entry_path("test_types", entry.national_code)

        expect(entry.reload).to be_active
        expect(DictionaryStatusChange.where(entity_uuid: entry.uuid).last.actor).to eq("Ana Machava <ana@hcm.gov.mz>")
      end

      it "retira uma entrada em vez de a apagar, para os nós locais saberem que saiu" do
        entry = create(:test_type)

        post retire_dictionary_entry_path("test_types", entry.national_code)

        expect(entry.reload).to be_retired
        expect(TestType.count).to eq(1)
      end

      it "promove os rascunhos em bloco e retém os inutilizáveis" do
        usable = create(:test_type, :draft)
        usable.indicators << create(:indicator)
        usable.specimen_types << create(:specimen_type)
        unusable = create(:test_type, :draft)

        post promote_dictionary_path

        expect(usable.reload).to be_active
        expect(unusable.reload).to be_draft
      end
    end
  end

  describe "num nó local", mode: :local do
    it "não tem sequer rota para editar o dicionário" do
      expect(Rails.application.routes.url_helpers).not_to respond_to(:edit_dictionary_entry_path)
    end
  end
end
