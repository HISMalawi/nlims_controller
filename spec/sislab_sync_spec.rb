# frozen_string_literal: true

require "rails_helper"

RSpec.describe SislabSync do
  around do |example|
    described_class.reset!
    example.run
    described_class.reset!
  end

  def with_env(vars)
    original = ENV.to_hash
    vars.each { |key, value| value.nil? ? ENV.delete(key.to_s) : ENV[key.to_s] = value }
    described_class.reset!
    yield
  ensure
    ENV.replace(original)
    described_class.reset!
  end

  describe ".mode" do
    it "reads the mode from the environment" do
      with_env("SISLAB_SYNC_MODE" => "national") do
        expect(described_class.mode).to eq("national")
      end
    end

    it "accepts a mode in any casing or padding" do
      with_env("SISLAB_SYNC_MODE" => "  LOCAL ") do
        expect(described_class.mode).to eq("local")
      end
    end

    it "refuses to boot without a mode" do
      with_env("SISLAB_SYNC_MODE" => nil) do
        expect { described_class.mode }.to raise_error(described_class::InvalidMode, /is not set/)
      end
    end

    it "refuses to boot on an unknown mode" do
      with_env("SISLAB_SYNC_MODE" => "regional") do
        expect { described_class.mode }.to raise_error(described_class::InvalidMode, /not a valid mode/)
      end
    end
  end

  describe ".local? and .national?" do
    it "is local and not national in local mode" do
      with_env("SISLAB_SYNC_MODE" => "local") do
        expect(described_class).to be_local
        expect(described_class).not_to be_national
      end
    end

    it "is national and not local in national mode" do
      with_env("SISLAB_SYNC_MODE" => "national") do
        expect(described_class).to be_national
        expect(described_class).not_to be_local
      end
    end
  end

  # A node is a laboratory, and answers to its entry in the national register.
  # The code is the one thing an installation has to be told; the facility, the
  # name and the district are read from the register once it arrives.
  describe ".lab_code" do
    it "uses the configured laboratory code" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_LAB_CODE" => "HCM-LAB-CENTRAL") do
        expect(described_class.lab_code).to eq("HCM-LAB-CENTRAL")
        expect(described_class.node_code).to eq("HCM-LAB-CENTRAL")
      end
    end

    # Every node deployed before the register existed sets this, and it meant
    # the same thing.
    it "still accepts the old node code" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_LAB_CODE" => nil,
               "SISLAB_SYNC_NODE_CODE" => "HCM") do
        expect(described_class.lab_code).to eq("HCM")
      end
    end

    # A local node without a code cannot address anything it pushes upwards, so
    # it must fail at boot rather than sync under a blank identity.
    it "requires a code in local mode" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_LAB_CODE" => nil,
               "SISLAB_SYNC_NODE_CODE" => nil) do
        expect { described_class.lab_code }.to raise_error(described_class::InvalidMode, /LAB_CODE is required/)
      end
    end

    it "defaults to NATIONAL in national mode" do
      with_env("SISLAB_SYNC_MODE" => "national", "SISLAB_SYNC_LAB_CODE" => nil,
               "SISLAB_SYNC_NODE_CODE" => nil) do
        expect(described_class.node_code).to eq("NATIONAL")
      end
    end
  end

  describe ".facility_code" do
    it "reads the health facility out of this node's entry in the register" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_LAB_CODE" => "HCM-LAB-CENTRAL") do
        create(:lab, national_code: "HCM-LAB-CENTRAL", facility_code: "HCM", name: "Laboratório Central")

        expect(described_class.facility_code).to eq("HCM")
        expect(described_class.node_name).to eq("Laboratório Central")
      end
    end

    # A node installed before the capital has published its entry still has to
    # work, and its own code is a stable enough prefix for a tracking number.
    it "falls back to the laboratory code before the register arrives" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_LAB_CODE" => "HCM-LAB-CENTRAL") do
        expect(described_class.facility_code).to eq("HCM-LAB-CENTRAL")
      end
    end
  end

  describe ".tls_terminated?" do
    it "assumes a proxy terminates TLS when nothing says otherwise" do
      with_env("SISLAB_SYNC_TLS_TERMINATED" => nil) do
        expect(described_class).to be_tls_terminated
      end
    end

    it "takes false to mean the node is reached over plain HTTP" do
      with_env("SISLAB_SYNC_TLS_TERMINATED" => "false") do
        expect(described_class).not_to be_tls_terminated
      end
    end

    it "accepts the opt-out in any casing or padding" do
      with_env("SISLAB_SYNC_TLS_TERMINATED" => " FALSE ") do
        expect(described_class).not_to be_tls_terminated
      end
    end

    # Anything other than an explicit false keeps TLS assumed: a typo in the
    # deployment environment should not quietly downgrade a node.
    it "keeps TLS assumed on an unrecognised value" do
      with_env("SISLAB_SYNC_TLS_TERMINATED" => "no") do
        expect(described_class).to be_tls_terminated
      end
    end
  end

  describe ".version" do
    it "reads the VERSION file" do
      expect(described_class.version).to match(/\A\d+\.\d+\.\d+/)
    end
  end
end
