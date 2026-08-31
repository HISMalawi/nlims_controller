# frozen_string_literal: true

require "rails_helper"

RSpec.describe DictionaryPullJob do
  around do |example|
    original = ENV.fetch("SISLAB_SYNC_NATIONAL_URL", nil)
    example.run
    ENV["SISLAB_SYNC_NATIONAL_URL"] = original
  end

  it "does nothing on a node with no national node configured" do
    allow(SislabSync).to receive(:local?).and_return(true)
    ENV.delete("SISLAB_SYNC_NATIONAL_URL")
    allow(Dictionary::Puller).to receive(:from_env)

    described_class.new.perform

    expect(Dictionary::Puller).not_to have_received(:from_env)
  end

  context "when a national node is configured" do
    before do
      ENV["SISLAB_SYNC_NATIONAL_URL"] = "http://nacional.example"
      # The suite runs in both modes; these examples are about what a local node
      # does, so the mode is pinned rather than inherited from the environment.
      allow(SislabSync).to receive(:local?).and_return(true)
    end

    it "pulls" do
      puller = instance_double(Dictionary::Puller, call: nil, summary: "test_types=1 batches=1")
      allow(puller).to receive(:call).and_return(puller)
      allow(Dictionary::Puller).to receive(:from_env).and_return(puller)

      described_class.new.perform

      expect(puller).to have_received(:call)
    end

    # The link to the capital being down is an ordinary condition at a
    # laboratory, not a bug to retry into a queue. It is on the cursor already.
    it "swallows an unreachable national node" do
      allow(Dictionary::Puller).to receive(:from_env)
        .and_raise(Dictionary::Puller::TransportError, "unreachable")

      expect { described_class.new.perform }.not_to raise_error
    end

    it "lets a real bug through" do
      allow(Dictionary::Puller).to receive(:from_env).and_raise(NoMethodError, "undefined method")

      expect { described_class.new.perform }.to raise_error(NoMethodError)
    end
  end

  it "does nothing on a national node" do
    allow(SislabSync).to receive(:local?).and_return(false)
    allow(Dictionary::Puller).to receive(:from_env)

    described_class.new.perform

    expect(Dictionary::Puller).not_to have_received(:from_env)
  end
end
