# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiKey do
  describe ".issue!" do
    it "returns a token in the documented shape" do
      _key, token = issue_key

      expect(token).to match(/\Assk_dev_[a-z0-9]{8}_[A-Za-z0-9]{32}\z/)
    end

    it "stores only the digest of the token" do
      key, token = issue_key

      expect(key.key_digest).to eq(Digest::SHA256.hexdigest(token))
      expect(key.attributes.values).not_to include(token)
    end

    it "gives every key a distinct prefix" do
      prefixes = Array.new(5) { issue_key.first.prefix }

      expect(prefixes.uniq.length).to eq(5)
    end

    it "refuses a scope that is not in the catalogue" do
      expect { issue_key(scopes: %w[orders:read orders:destroy]) }
        .to raise_error(ActiveRecord::RecordInvalid, /orders:destroy/)
    end
  end

  describe ".authenticate" do
    it "accepts the issued token" do
      key, token = issue_key

      expect(described_class.authenticate(token)).to eq(key)
    end

    it "rejects a token whose secret has been altered" do
      _key, token = issue_key
      tampered = "#{token[0..-2]}#{token[-1] == 'a' ? 'b' : 'a'}"

      expect(described_class.authenticate(tampered)).to be_nil
    end

    it "rejects an unknown prefix" do
      expect(described_class.authenticate("ssk_dev_zzzzzzzz_#{'a' * 32}")).to be_nil
    end

    it "rejects a token from another environment" do
      _key, token = issue_key

      expect(described_class.authenticate(token.sub("ssk_dev_", "ssk_prod_"))).to be_nil
    end

    it "rejects anything that is not a token" do
      expect(described_class.authenticate(nil)).to be_nil
      expect(described_class.authenticate("")).to be_nil
      expect(described_class.authenticate("Bearer something")).to be_nil
      expect(described_class.authenticate("ssk_dev_short")).to be_nil
    end

    it "stops accepting a revoked key immediately" do
      key, token = issue_key
      key.revoke!

      expect(described_class.authenticate(token)).to be_nil
    end

    it "stops accepting an expired key" do
      key, token = issue_key
      key.update!(expires_at: 1.minute.ago)

      expect(described_class.authenticate(token)).to be_nil
    end

    it "accepts a key whose expiry is still ahead" do
      _key, token = issue_key(expires_at: 1.hour.from_now)

      expect(described_class.authenticate(token)).to be_present
    end

    it "rejects a key belonging to a disabled client" do
      client = create(:api_client)
      _key, token = issue_key(api_client: client)
      client.update!(active: false)

      expect(described_class.authenticate(token)).to be_nil
    end
  end

  describe "rotation" do
    it "lets the replacement work while the old key is still live, then cuts the old one off" do
      client = create(:api_client)
      old_key, old_token = issue_key(api_client: client)
      _new_key, new_token = issue_key(api_client: client)

      expect(described_class.authenticate(old_token)).to be_present
      expect(described_class.authenticate(new_token)).to be_present

      old_key.revoke!

      expect(described_class.authenticate(old_token)).to be_nil
      expect(described_class.authenticate(new_token)).to be_present
    end
  end

  describe "#allows?" do
    it "answers on the scopes it was issued with" do
      key, = issue_key(scopes: %w[orders:read dictionary:read])

      expect(key).to be_allows("orders:read")
      expect(key).not_to be_allows("orders:write")
    end
  end

  describe "#touch_last_used!" do
    it "records the first use" do
      key, = issue_key

      expect { key.touch_last_used! }.to change { key.reload.last_used_at }.from(nil)
    end

    # Otherwise every read turns into a write.
    it "does not write again within the resolution window" do
      key, = issue_key
      key.touch_last_used!
      first = key.reload.last_used_at

      key.touch_last_used!

      expect(key.reload.last_used_at).to eq(first)
    end

    it "writes again once the window has passed" do
      key, = issue_key
      key.touch_last_used!(now: 5.minutes.ago)

      expect { key.touch_last_used! }.to change { key.reload.last_used_at }
    end
  end

  describe "#masked_token" do
    it "shows the prefix and hides the secret" do
      key, token = issue_key

      expect(key.masked_token).to include(key.prefix)
      expect(token).not_to include(key.masked_token)
    end
  end
end
