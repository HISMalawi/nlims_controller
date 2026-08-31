# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  describe ".authenticate" do
    it "devolve o utilizador com a palavra-passe certa" do
      user = create(:user, email: "ana@hcm.gov.mz", password: "palavra-passe-boa")

      expect(described_class.authenticate(email: "ana@hcm.gov.mz", password: "palavra-passe-boa")).to eq(user)
    end

    it "devolve nil — e não false — com a palavra-passe errada" do
      create(:user, email: "ana@hcm.gov.mz")

      expect(described_class.authenticate(email: "ana@hcm.gov.mz", password: "errada")).to be_nil
    end

    it "devolve nil para um endereço desconhecido" do
      expect(described_class.authenticate(email: "ninguem@hcm.gov.mz", password: "seja o que for")).to be_nil
    end

    it "devolve nil para uma conta desactivada, mesmo com a palavra-passe certa" do
      create(:user, :disabled, email: "saiu@hcm.gov.mz", password: "palavra-passe-boa")

      expect(described_class.authenticate(email: "saiu@hcm.gov.mz", password: "palavra-passe-boa")).to be_nil
    end
  end

  describe "o endereço" do
    it "é guardado em minúsculas e sem espaços" do
      user = create(:user, email: "  Ana@HCM.gov.MZ  ")

      expect(user.email).to eq("ana@hcm.gov.mz")
    end

    it "é único depois de normalizado" do
      create(:user, email: "ana@hcm.gov.mz")

      expect { create(:user, email: "ANA@hcm.gov.mz") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "a palavra-passe" do
    it "tem um comprimento mínimo" do
      user = build(:user, password: "curta")

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end
  end

  it "identifica-se pelo nome e endereço quando é o actor de uma transição" do
    user = build(:user, name: "Ana Machava", email: "ana@hcm.gov.mz")

    expect(user.to_actor).to eq("Ana Machava <ana@hcm.gov.mz>")
  end
end
