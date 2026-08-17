# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dictionary feed", type: :request do
  let(:token) { issue_key(scopes: %w[dictionary:read]).last }

  def get_changes(params = {}, key: token)
    get "/api/v3/dictionary/changes", params: params, headers: auth_headers(key)
  end

  def entries
    response.parsed_body["data"]
  end

  def meta
    response.parsed_body["meta"]
  end

  describe "authorisation" do
    it "needs a key" do
      get "/api/v3/dictionary/changes"

      expect(response).to have_http_status(:unauthorized)
    end

    it "needs the dictionary scope" do
      get_changes({}, key: issue_key(scopes: %w[orders:read]).last)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("insufficient_scope")
    end
  end

  describe "the feed" do
    it "is empty on a dictionary that has published nothing" do
      create(:test_type, :draft)

      get_changes

      expect(response).to have_http_status(:ok)
      expect(entries).to eq([])
    end

    it "returns published entries oldest first with the cursor to send next" do
      first = create(:specimen_type)
      second = create(:test_type)

      get_changes

      expect(entries.pluck("national_code")).to eq([ first.national_code, second.national_code ])
      expect(meta).to include("cursor" => 0, "next_cursor" => second.reload.revision, "has_more" => false)
    end

    it "returns only what happened after the cursor" do
      first = create(:test_type)
      second = create(:test_type)

      get_changes({ since: first.revision })

      expect(entries.pluck("national_code")).to eq([ second.national_code ])
    end

    it "says when there is more to come" do
      create_list(:test_type, 3)

      get_changes({ limit: 2 })

      expect(entries.length).to eq(2)
      expect(meta["has_more"]).to be(true)
    end

    it "drains completely when the client follows the cursor" do
      create_list(:test_type, 5)
      seen = []
      cursor = 0

      loop do
        get_changes({ since: cursor, limit: 2 })
        seen.concat(entries.pluck("national_code"))
        cursor = meta["next_cursor"]
        break unless meta["has_more"]
      end

      expect(seen.length).to eq(5)
      expect(seen.uniq.length).to eq(5)
    end

    it "can be narrowed to the entity types a client cares about" do
      create(:specimen_type)
      test_type = create(:test_type)

      get_changes({ entities: "test_types" })

      expect(entries.pluck("national_code")).to eq([ test_type.national_code ])
    end

    it "names the entity type a client got wrong instead of quietly returning less" do
      get_changes({ entities: "test_types,patients" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "message")).to include("patients")
    end

    it "carries links by national code" do
      test_type = create(:test_type)
      specimen_type = create(:specimen_type)
      test_type.specimen_types << specimen_type

      get_changes({ entities: "test_types" })

      expect(entries.first["specimen_types"]).to eq([ { "national_code" => specimen_type.national_code } ])
    end

    it "carries a retirement so a node learns the entry is gone" do
      test_type = create(:test_type)
      test_type.retire!

      get_changes

      expect(entries.first).to include("status" => "retired")
      expect(entries.first["deleted_at"]).to be_present
    end

    it "never leaks a draft" do
      create(:test_type, :draft)
      create(:indicator, :draft)

      get_changes

      expect(entries).to eq([])
    end

    it "caps the batch size a client can ask for" do
      create_list(:test_type, 3)

      get_changes({ limit: 100_000 })

      expect(entries.length).to eq(3)
    end
  end

  describe "straight reads" do
    it "lists the current catalogue of one entity type" do
      test_type = create(:test_type)
      create(:specimen_type)

      get "/api/v3/dictionary/test_types", headers: auth_headers(token)

      expect(response).to have_http_status(:ok)
      expect(entries.pluck("national_code")).to eq([ test_type.national_code ])
    end

    # An EMR building an order form wants what is current, not what is gone.
    it "leaves out drafts and retirements" do
      active = create(:test_type)
      create(:test_type, :draft)
      create(:test_type).retire!

      get "/api/v3/dictionary/test_types", headers: auth_headers(token)

      expect(entries.pluck("national_code")).to eq([ active.national_code ])
    end

    it "refuses an entity type that is not part of the dictionary" do
      get "/api/v3/dictionary/orders", headers: auth_headers(token)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "field")).to eq("entity_type")
    end
  end

  # Both modes answer this: a local node pulls from the national one, a SISLAB
  # pulls from its local node, and the contract has to be the same or the second
  # hop needs its own client.
  it "is served in this node's mode" do
    create(:test_type)

    get_changes

    expect(response).to have_http_status(:ok)
    expect(entries.length).to eq(1)
  end
end
