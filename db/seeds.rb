# frozen_string_literal: true

# A node with something on it.
#
# The interface built in S11 is mostly empty on a fresh database, which makes it
# impossible to show anyone and easy to believe is broken. This fills a
# development node with a small but real dataset: a dictionary that hangs
# together, orders at every stage of their lifecycle, a referred sample, and an
# outbox with something stuck in it.
#
# Real, not fabricated: orders are raised through OrderRequest and walked with
# `transition_to!`, exactly as the EMR and the SISLAB would drive them. That is
# what produces the status history, the revisions and the outbox rows the
# screens are actually reading — a seed that wrote those tables directly would
# show a system that cannot happen.
#
# Development only, and enforced rather than intended.
#
# Production nodes get their dictionary from the national one and their orders
# from the laboratory. The test database has to start empty, or every spec runs
# against a dictionary it did not create — `db:prepare` seeds whenever it
# creates a database, so this file runs in the test environment unless it says
# otherwise, and the failures that follow point at the spec rather than here.

unless Rails.env.development?
  warn "db/seeds.rb makes demo data for development only — skipped in #{Rails.env}."
  return
end

module Seeds
  PASSWORD = "palavra-passe-demo"

  FACILITY = SislabSync.node_code
  LAB = "#{SislabSync.node_code}-LAB"

  # Where the demo credentials are written instead of being printed.
  #
  # bin/docker-entrypoint runs db:prepare, and db:prepare seeds whenever it
  # creates a database — so `docker compose up` on a fresh volume runs this
  # file, and anything it puts on stdout goes into the container log, gets
  # shipped wherever logs are shipped, and is pasted into chats and issues
  # along with the rest of the boot output. An API key is a bearer token: it
  # is the whole credential, and it works for anybody who reads it.
  CREDENTIALS_PATH = "tmp/demo_credentials.txt"

  # A demo key that outlives the demo is a live credential nobody remembers
  # issuing. This one stops working on its own.
  KEY_LIFETIME = 30.days

  class << self
    def call
      say "Semeando o nó #{SislabSync.node_code} (#{SislabSync.mode})"

      users
      client = api_client
      dictionary

      if Order.exists?
        say "  já há pedidos — nada de novo a semear"
      else
        orders(client)
        referral if SislabSync.local?
        stuck_event if SislabSync.local?
      end

      nodes if SislabSync.national?

      write_credentials
    end

    private

    # The secrets go to a file on the node, readable by whoever ran the seed and
    # nobody else. The log gets the path.
    def write_credentials
      path = Rails.root.join(CREDENTIALS_PATH)
      FileUtils.mkdir_p(path.dirname)

      File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
        file.puts "Credenciais de demonstração — #{SislabSync.node_code} (#{SislabSync.mode})"
        file.puts "Geradas por db/seeds.rb em #{Time.current.iso8601}. Não são para nenhum nó real."
        file.puts
        User.order(:id).each { |user| file.puts "  #{user.role.ljust(9)} #{user.email}  #{PASSWORD}" }

        file.puts

        if @issued_token
          file.puts "  chave do EMR de demonstração (expira #{@issued_expiry.to_date}):"
          file.puts "  #{@issued_token}"
        else
          # Re-running must not look as though the key were lost, and cannot
          # reprint it: only its digest was ever stored.
          file.puts "  o EMR de demonstração já tinha uma chave válida — este ficheiro não a pode repetir."
          file.puts "  Revogue-a na interface e volte a correr db:seed para obter outra."
        end
      end

      File.chmod(0o600, path)

      say "Pronto. Credenciais em #{CREDENTIALS_PATH} (não passam pelo log)."
    end

    # find_or_create so re-running does not reset a password somebody is using.
    def users
      [
        { name: "Ana Machava", email: "ana@#{domain}", role: User::ADMIN },
        { name: "Bento Cossa", email: "bento@#{domain}", role: User::OPERATOR }
      ].each do |attributes|
        next if User.exists?(email: attributes[:email])

        User.create!(**attributes, password: PASSWORD, facility_code: FACILITY)
        say "  utilizador #{attributes[:email]} (#{attributes[:role]})"
      end
    end

    # An EMR to raise the orders as, so they carry a source and an actor rather
    # than appearing from nowhere.
    def api_client
      client = ApiClient.find_or_create_by!(name: "EMR de demonstração") do |record|
        record.kind = "emr"
        record.facility_code = FACILITY
        record.active = true
      end

      if client.api_keys.usable.none?
        @issued_expiry = KEY_LIFETIME.from_now

        key, @issued_token = ApiKey.issue!(
          api_client: client,
          scopes: %w[orders:write orders:read results:read dictionary:read],
          expires_at: @issued_expiry,
          issued_by: "db:seed"
        )

        # The prefix identifies the key without being the key. It is what is
        # already shown on the interface, and it is enough to revoke by.
        say "  chave do EMR de demonstração emitida (#{key.prefix}), expira #{@issued_expiry.to_date}"
      end

      client
    end

    # Small, but linked the way the real catalogue is: a test with no indicators
    # reports nothing and a test with no specimen type cannot be collected, and
    # both are exactly what the quality report holds a promotion back for.
    def dictionary
      return say("  dicionário já tem entradas") if TestType.exists?
      return national_catalogue if SislabSync.national? && Dictionary::SnapshotSource.available?

      bioquimica = Department.create!(name: "Bioquímica", status: DictionaryEntry::ACTIVE)
      hematologia = Department.create!(name: "Hematologia", status: DictionaryEntry::ACTIVE)

      blood = specimen("Sangue total")
      serum = specimen("Soro")
      urine = specimen("Urina")

      haemoglobin = indicator("Hemoglobina", unit: "g/dL", lower: 12, upper: 16)
      leucocytes = indicator("Leucócitos", unit: "10³/µL", lower: 4, upper: 11)
      glucose = indicator("Glicemia", unit: "mg/dL", lower: 70, upper: 110)
      creatinine = indicator("Creatinina", unit: "mg/dL", lower: 0.6, upper: 1.2)

      hemogram = test_type("Hemograma completo", department: hematologia,
                           specimens: [ blood ], indicators: [ haemoglobin, leucocytes ])
      glycaemia = test_type("Glicemia em jejum", department: bioquimica,
                            specimens: [ serum, blood ], indicators: [ glucose ])
      renal = test_type("Função renal", department: bioquimica,
                        specimens: [ serum ], indicators: [ creatinine ])

      panel = TestPanel.create!(name: "Painel básico de admissão", status: DictionaryEntry::ACTIVE)
      panel.test_types << [ hemogram, glycaemia ]

      # Left as a draft on purpose: the promotion screen needs something to
      # promote, and the quality report something to hold back — this one has
      # neither indicators nor specimen types.
      TestType.create!(name: "Urocultura", department: bioquimica, status: DictionaryEntry::DRAFT)
      urine

      [ "Amostra hemolisada", "Volume insuficiente", "Tubo mal identificado", "Amostra recebida sem requisição" ]
        .each { |name| RejectionReason.create!(name: name, status: DictionaryEntry::ACTIVE) }

      say "  dicionário: #{Dictionary.published_counts.values.sum} entradas publicadas, 1 rascunho, #{renal.national_code} inclusive"
    end

    # The national node owns the catalogue, so a national demo gets the real
    # one — the same entries `rake dictionary:seed` puts on a node being stood
    # up — and the orders below are raised against it. A local node keeps the
    # four tests invented here: its dictionary arrives from the capital, and a
    # small one is easier to read on the screens.
    def national_catalogue
      seed = Dictionary::Seed.new(actor: "semente de demonstração").call

      # Left as a draft on purpose, as below: the promotion screen needs
      # something to promote.
      TestType.create!(name: "Urocultura", department: Department.active.first, status: DictionaryEntry::DRAFT)

      say "  dicionário: #{seed.published} entradas do catálogo mLab publicadas, 1 rascunho"
    end

    def specimen(name)
      SpecimenType.create!(name: name, status: DictionaryEntry::ACTIVE)
    end

    def indicator(name, unit:, lower:, upper:)
      Indicator.create!(name: name, unit: unit, value_type: "Numeric", status: DictionaryEntry::ACTIVE).tap do |record|
        record.indicator_ranges.create!(sex: "Both", range_lower: lower, range_upper: upper,
                                        interpretation: "Normal")
      end
    end

    def test_type(name, department:, specimens:, indicators:)
      TestType.create!(name: name, department: department, target_tat: "24h",
                       status: DictionaryEntry::ACTIVE).tap do |record|
        record.specimen_types << specimens
        record.indicators << indicators
      end
    end

    # One order per stage, so every status badge on the orders screen has
    # something behind it and the history on the detail screen is a real walk
    # rather than a single row.
    def orders(client)
      raise_order(client, patient: :ana)

      accepted = raise_order(client, patient: :bento)
      accepted.claim!(lab_code: LAB, actor: "Lab. de Bioquímica")

      collected = raise_order(client, patient: :carla)
      collected.claim!(lab_code: LAB, actor: "Lab. de Bioquímica")
      collected.transition_to!(Order::SPECIMEN_COLLECTED, actor: "tec. Mabjaia")

      running = raise_order(client, patient: :david, priority: "urgent")
      walk_to_in_progress(running)

      completed = raise_order(client, patient: :elsa)
      walk_to_in_progress(completed)
      report(completed)
      completed.transition_to!(Order::COMPLETED, actor: "Dra. Sitoe", reason: "todos os testes concluídos")

      rejected = raise_order(client, patient: :fatima)
      rejected.claim!(lab_code: LAB, actor: "Lab. de Bioquímica")
      rejected.reject!(reason: RejectionReason.active.first, actor: "tec. Mabjaia",
                       note: "recebida à temperatura ambiente")

      say "  #{Order.count} pedidos, #{OrderTest.count} testes, #{TestResult.count} resultados"
    end

    def walk_to_in_progress(order)
      order.claim!(lab_code: LAB, actor: "Lab. de Bioquímica")
      order.transition_to!(Order::SPECIMEN_COLLECTED, actor: "tec. Mabjaia")
      order.transition_to!(Order::IN_PROGRESS, actor: "tec. Mabjaia")
    end

    # Values inside the reference ranges seeded above, so a reader can see the
    # ranges doing their job rather than a column of numbers meaning nothing.
    VALUES = { "Hemoglobina" => "13.4", "Leucócitos" => "7.2", "Glicemia" => "92", "Creatinina" => "0.9" }.freeze

    def report(order)
      order.order_tests.each do |order_test|
        order_test.transition_to!(OrderTest::IN_PROGRESS, actor: "tec. Mabjaia")

        order_test.test_type.indicators.each do |indicator|
          TestResult.record!(
            order_test: order_test,
            indicator: indicator,
            value: VALUES.fetch(indicator.name, "normal"),
            unit: indicator.unit,
            recorded_by: "tec. Mabjaia"
          )
        end

        order_test.transition_to!(OrderTest::COMPLETED, actor: "Dra. Sitoe")
      end
    end

    PATIENTS = {
      ana: { name: "Ana Cristina Mondlane", sex: "F", birthdate: Date.new(1991, 4, 12), national_id: "110100200001A" },
      bento: { name: "Bento José Cossa", sex: "M", birthdate: Date.new(1978, 11, 3), national_id: "110100200002B" },
      carla: { name: "Carla Nhantumbo", sex: "F", birthdate: Date.new(2015, 6, 21) },
      david: { name: "David Chirindza", sex: "M", birthdate: Date.new(1965, 1, 30), national_id: "110100200004D" },
      elsa: { name: "Elsa Muianga", sex: "F", birthdate: Date.new(1988, 9, 9), national_id: "110100200005E" },
      fatima: { name: "Fátima Bié", sex: "F", birthdate: Date.new(2001, 2, 14) },
      gilda: { name: "Gilda Tembe", sex: "F", birthdate: Date.new(1995, 7, 7), national_id: "110100200007G" }
    }.freeze

    def raise_order(client, patient:, priority: "routine", tests: nil)
      tests ||= [ { test_panel: { national_code: TestPanel.active.first.national_code } } ]

      OrderRequest.new({
        patient: PATIENTS.fetch(patient),
        order: {
          sending_facility_code: FACILITY,
          receiving_lab_code: LAB,
          priority: priority,
          requested_by: "Dr. J. Sitoe",
          order_location: "Consulta externa",
          specimen_type: { national_code: SpecimenType.active.first.national_code },
          collected_at: Time.current
        },
        tests: tests
      }, api_client: client).create!
    end

    # A sample sent to another laboratory and still in transit, so the referrals
    # screen has a transport time to be waiting on.
    def referral
      order = raise_order(ApiClient.find_by(name: "EMR de demonstração"), patient: :gilda)
      walk_to_in_progress(order)

      Referral.dispatch!(order: order, to_facility_code: "HPM", to_lab_code: "HPM-LAB",
                         courier: "Transporte provincial", remarks: "Caixa isotérmica, saída às 07h30")

      say "  1 amostra referida para HPM-LAB, ainda em trânsito"
    end

    # Something for the sync queue to show. The national node is unreachable on
    # a standalone development node, which is precisely the condition an
    # operator opens that screen in.
    def stuck_event
      event = OutboxEvent.pending.order(:id).first
      return if event.nil?

      event.mark_failed!("Errno::ECONNREFUSED: não foi possível ligar ao nó nacional")
      SyncCursor.for(SyncCursor::HEARTBEAT)
                .record_failure!("Errno::ECONNREFUSED: não foi possível ligar ao nó nacional")

      say "  1 evento retido na fila de sincronização, com erro"
    end

    # The national node's own screen needs nodes on it, and one of them needs to
    # have gone quiet.
    def nodes
      return say("  nós já registados") if Node.exists?

      Node.heard_from!("HCM", name: "Hospital Central de Maputo", version: SislabSync.version,
                              dictionary_cursor: Dictionary.cursor, outbox_pending: 0)
      Node.heard_from!("HPM", name: "Hospital Provincial de Matola", version: SislabSync.version,
                              dictionary_cursor: [ Dictionary.cursor - 4, 0 ].max, outbox_pending: 12)

      silent = Node.heard_from!("HPQ", name: "Hospital Provincial de Quelimane", version: "1.9.2",
                                       dictionary_cursor: 0, outbox_pending: 143, outbox_failing: 143)
      silent.update_column(:last_seen_at, 2.days.ago)

      say "  3 nós, 1 sem contacto há dois dias"
    end

    def domain
      SislabSync.national? ? "misau.gov.mz" : "#{SislabSync.node_code.downcase}.gov.mz"
    end

    def say(message)
      puts message
    end
  end
end

Seeds.call
