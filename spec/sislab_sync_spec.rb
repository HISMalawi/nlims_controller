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

  # A node is a health facility, and answers to its entry in the national
  # register. The code is the one thing an installation has to be told; the
  # name, the district and the province are read from the register once it
  # arrives, and so are the laboratories inside the unit.
  describe ".facility_code" do
    it "uses the configured health facility code" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_FACILITY_CODE" => "HCM") do
        expect(described_class.facility_code).to eq("HCM")
        expect(described_class.node_code).to eq("HCM")
      end
    end

    # Every node deployed before the register existed sets this, and it has
    # always meant "the code this node answers to".
    it "still accepts the old node code" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_FACILITY_CODE" => nil,
               "SISLAB_SYNC_NODE_CODE" => "HCM") do
        expect(described_class.facility_code).to eq("HCM")
      end
    end

    # A local node without a code cannot address anything it pushes upwards, so
    # it must fail at boot rather than sync under a blank identity.
    it "requires a code in local mode" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_FACILITY_CODE" => nil,
               "SISLAB_SYNC_NODE_CODE" => nil, "SISLAB_SYNC_LAB_CODE" => nil) do
        expect { described_class.facility_code }
          .to raise_error(described_class::InvalidMode, /FACILITY_CODE is required/)
      end
    end

    # The old variable named a laboratory, and a node is not one. Reading it as
    # a facility code would have the node addressing its samples to a register
    # entry of the wrong kind, so it is refused with the rename in the message.
    it "refuses the laboratory code left over from when a node was a laboratory" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_FACILITY_CODE" => nil,
               "SISLAB_SYNC_NODE_CODE" => nil, "SISLAB_SYNC_LAB_CODE" => "HCM-LAB") do
        expect { described_class.facility_code }
          .to raise_error(described_class::InvalidMode, /SISLAB_SYNC_FACILITY_CODE/)
      end
    end

    it "defaults to NATIONAL in national mode" do
      with_env("SISLAB_SYNC_MODE" => "national", "SISLAB_SYNC_FACILITY_CODE" => nil,
               "SISLAB_SYNC_NODE_CODE" => nil) do
        expect(described_class.node_code).to eq("NATIONAL")
      end
    end
  end

  describe ".facility" do
    it "reads this node's name out of its entry in the register" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_FACILITY_CODE" => "HCM") do
        create(:facility, national_code: "HCM", name: "Hospital Central de Maputo")

        expect(described_class.node_name).to eq("Hospital Central de Maputo")
      end
    end

    # A node installed before the capital has published its entry still has to
    # work, and its own code is a stable enough thing to call itself.
    it "calls itself by its code before the register arrives" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_FACILITY_CODE" => "HCM") do
        expect(described_class.facility).to be_nil
        expect(described_class.node_name).to eq("HCM")
      end
    end
  end

  describe ".labs" do
    it "lists the laboratories of this unit and nobody else's" do
      with_env("SISLAB_SYNC_MODE" => "local", "SISLAB_SYNC_FACILITY_CODE" => "HCM") do
        mine = create(:lab, facility_code: "HCM", name: "Laboratório Central")
        create(:lab, facility_code: "HPM", name: "Laboratório Provincial")

        expect(described_class.labs).to eq([ mine ])
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
