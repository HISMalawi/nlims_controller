# frozen_string_literal: true

# LOINC curation, in the order it is actually done:
#
#   bin/rails dictionary:loinc:coverage
#   LOINC_CSV=tmp/Loinc.csv bin/rails dictionary:loinc:worksheet
#   # ... a laboratory person fills in the loinc_code column ...
#   LOINC_CSV=tmp/Loinc.csv bin/rails "dictionary:loinc:apply[tmp/loinc_worksheet.csv]"   # dry run
#   LOINC_CSV=tmp/Loinc.csv ACTOR="Ana Machava" APPLY=1 \
#     bin/rails "dictionary:loinc:apply[tmp/loinc_worksheet.csv]"
#
# The LOINC release is not in this repository and is not ours to put there: it
# is downloaded from loinc.org under its own licence. LOINC_CSV points at the
# `Loinc.csv` inside it.
namespace :dictionary do
  namespace :loinc do
    desc "Show how much of the dictionary carries a LOINC code"
    task coverage: "dictionary:national_only" do
      coverage = Dictionary::LoincCoverage.new

      puts "Cobertura LOINC:"
      puts coverage.summary
      puts format("  %-16s %5d activos  %5d com LOINC  %5d sem  %s",
                  "total", coverage.total, coverage.covered, coverage.missing,
                  coverage.percentage ? "#{coverage.percentage}%" : "—")
      puts "\nDetalhe: #{coverage.write_csv}"
    end

    desc "Write the curation worksheet, with candidates, to tmp/loinc_worksheet.csv"
    task worksheet: "dictionary:national_only" do
      catalogue = load_catalogue
      suggestions = Dictionary::LoincSuggestions.new(catalogue: catalogue)
      path = suggestions.write_csv

      puts "#{suggestions.rows.length} entradas por curar; #{suggestions.with_candidates} com candidatos."
      puts "Preencha a coluna loinc_code e aplique o mesmo ficheiro:"
      puts "  #{path}"
      puts "\nOs candidatos são uma ajuda de leitura, não uma decisão. Confirme cada um."
    end

    desc "Apply a filled-in worksheet (dry run unless APPLY=1; ACTOR required to apply)"
    task :apply, [ :path ] => "dictionary:national_only" do |_task, args|
      path = args[:path].presence || abort('Usage: bin/rails "dictionary:loinc:apply[caminho.csv]"')
      apply = ENV["APPLY"].present?
      actor = ENV["ACTOR"].presence

      abort("Set ACTOR to the person accepting these codes.") if apply && actor.nil?

      mapping = Dictionary::LoincMapping.new(
        path: path,
        actor: actor || "simulação",
        catalogue: load_catalogue(required: false),
        dry_run: !apply
      ).call

      puts(apply ? "Aplicado por #{actor}:" : "Simulação (APPLY=1 para aplicar):")
      puts mapping.summary

      if mapping.failed?
        puts "\nRecusadas — nada foi aplicado:"
        mapping.rejected.first(20).each do |outcome|
          puts format("  linha %-5d %-16s %-14s %s", outcome.line, outcome.entity_type,
                      outcome.loinc_code, outcome.detail)
        end
        puts "  ..." if mapping.rejected.length > 20
      end

      puts "\nResultado por linha: #{mapping.write_csv}"
      Rake::Task["dictionary:loinc:coverage"].invoke unless mapping.failed? || !apply

      exit(1) if mapping.failed?
    end

    # The catalogue is what turns "looks like a LOINC code" into "is one". Every
    # task takes it the same way and says the same thing when it is missing.
    def load_catalogue(required: true)
      path = ENV["LOINC_CSV"].presence

      if path.nil?
        message = "LOINC_CSV is not set — download the LOINC release from loinc.org and point it at its Loinc.csv."
        abort(message) if required

        puts "LOINC_CSV não definido: os códigos só serão verificados na forma, não contra o LOINC."
        return nil
      end

      catalogue = Dictionary::LoincCatalogue.from_path(path)
      puts "LOINC: #{catalogue.size} códigos carregados de #{path}"
      catalogue
    rescue Dictionary::LoincCatalogue::MissingFile => e
      abort(e.message)
    end
  end
end
