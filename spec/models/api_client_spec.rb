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

  # Issuing a key used to mean typing a facility code and a laboratory code into
  # a form, and the pair then decided whether the client's requests were
  # answered. On a node that is a health facility the unit is already known, and
  # the laboratory is not on the key at all: one mLab instance speaks for every
  # laboratory in the unit, so a laboratory on the key would be right for one of
  # them and wrong for the rest.
  describe "the identity it inherits", mode: :local do
    it "takes this node's unit, so the form need not ask" do
      client = create(:api_client, kind: "emr", facility_code: nil, lab_code: nil)

      expect(client.facility_code).to eq(SislabSync.facility_code)
      expect(client.lab_code).to be_nil
    end

    it "leaves alone a code that was given on purpose" do
      expect(create(:api_client, facility_code: "QUELIMANE").facility_code).to eq("QUELIMANE")
    end

    # A node-to-node client speaks for whoever is on the other end of it.
    it "gives a node client no codes at all" do
      client = create(:api_client, :node)

      expect(client.facility_code).to be_nil
      expect(client.lab_code).to be_nil
    end
  end

  it "takes its keys with it when deleted" do
    client = create(:api_client)
    issue_key(api_client: client)

    expect { client.destroy! }.to change(ApiKey, :count).by(-1)
  end
end
