# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiClient do
  it "gets a uuid on creation" do
    expect(create(:api_client).uuid).to match(/\A[0-9a-f-]{36}\z/)
  end

  it "rejects an unknown kind" do
    expect { create(:api_client, kind: "hospital") }
      .to raise_error(ActiveRecord::RecordInvalid, /Kind/)
  end

  # A key that cannot say which facility it speaks for cannot be checked against
  # the data it is touching.
  it "requires a facility code on clients that act for one" do
    expect { create(:api_client, kind: "emr", facility_code: nil) }
      .to raise_error(ActiveRecord::RecordInvalid, /Facility code/)
  end

  it "does not require a facility code on a node client" do
    expect(create(:api_client, :node)).to be_persisted
  end

  describe "#acts_for_facility?" do
    it "accepts its own facility and refuses another" do
      client = create(:api_client, facility_code: "HCM")

      expect(client).to be_acts_for_facility("HCM")
      expect(client).not_to be_acts_for_facility("QUELIMANE")
    end

    it "accepts any facility when it is not pinned to one" do
      expect(create(:api_client, :node)).to be_acts_for_facility("HCM")
    end
  end

  describe "#acts_for_lab?" do
    it "accepts its own lab and refuses another" do
      client = create(:api_client, :sislab, lab_code: "HCM-LAB-BIOQ")

      expect(client).to be_acts_for_lab("HCM-LAB-BIOQ")
      expect(client).not_to be_acts_for_lab("HCM-LAB-MICRO")
    end

    # An EMR speaks for the whole facility; it has no laboratory of its own.
    it "accepts any lab when it is not pinned to one" do
      expect(create(:api_client, kind: "emr", lab_code: nil)).to be_acts_for_lab("HCM-LAB-BIOQ")
    end
  end

  it "takes its keys with it when deleted" do
    client = create(:api_client)
    issue_key(api_client: client)

    expect { client.destroy! }.to change(ApiKey, :count).by(-1)
  end
end
