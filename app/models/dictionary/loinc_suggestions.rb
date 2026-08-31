# frozen_string_literal: true

require "csv"

module Dictionary
  # A worksheet: every active entry still without a LOINC code, with up to three
  # candidates beside it for a curator to accept, replace or ignore.
  #
  # The suggestions are a reading aid and nothing more. The dictionary is in
  # Portuguese and LOINC is in English, so matching is done through a small
  # glossary of clinical terms — enough to find "Hemoglobina" under haemoglobin,
  # not enough to be trusted. The `loinc_code` column is left empty in every
  # row, including the ones with a confident-looking match, because a worksheet
  # that arrives pre-filled gets handed back unread and the wrong codes then
  # travel to every laboratory in the country.
  class LoincSuggestions
    HEADERS = %w[
      entity_type national_code name loinc_code
      candidate_1 candidate_1_name candidate_2 candidate_2_name candidate_3 candidate_3_name
    ].freeze

    DEFAULT_PATH = "tmp/loinc_worksheet.csv"

    CANDIDATES = 3

    # Portuguese clinical vocabulary as LOINC spells it. Small and specific:
    # these are the words the imported catalogue actually uses, and a longer
    # list of guesses would produce more candidates rather than better ones.
    GLOSSARY = {
      "hemoglobina" => %w[hemoglobin],
      "hematocrito" => %w[hematocrit],
      "hemograma" => %w[cbc hemogram blood count],
      "leucocitos" => %w[leukocytes],
      "plaquetas" => %w[platelets],
      "eritrocitos" => %w[erythrocytes],
      "reticulocitos" => %w[reticulocytes],
      "glicemia" => %w[glucose],
      "glicose" => %w[glucose],
      "creatinina" => %w[creatinine],
      "ureia" => %w[urea],
      "acido" => %w[acid],
      "urico" => %w[urate],
      "colesterol" => %w[cholesterol],
      "trigliceridos" => %w[triglyceride],
      "bilirrubina" => %w[bilirubin],
      "proteinas" => %w[protein],
      "albumina" => %w[albumin],
      "fosfatase" => %w[phosphatase],
      "alcalina" => %w[alkaline],
      "transaminase" => %w[aminotransferase],
      "amilase" => %w[amylase],
      "lipase" => %w[lipase],
      "calcio" => %w[calcium],
      "potassio" => %w[potassium],
      "sodio" => %w[sodium],
      "cloro" => %w[chloride],
      "ferro" => %w[iron],
      "ferritina" => %w[ferritin],
      "magnesio" => %w[magnesium],
      "fosforo" => %w[phosphate],
      "gravidez" => %w[pregnancy],
      "urina" => %w[urine],
      "sangue" => %w[blood],
      "soro" => %w[serum],
      "plasma" => %w[plasma],
      "fezes" => %w[stool],
      "expectoracao" => %w[sputum],
      "liquor" => %w[cerebrospinal fluid],
      "cefalorraquidiano" => %w[cerebrospinal],
      "cultura" => %w[culture],
      "urocultura" => %w[urine culture],
      "hemocultura" => %w[blood culture],
      "coprocultura" => %w[stool culture],
      "baciloscopia" => %w[acid fast stain],
      "tuberculose" => %w[tuberculosis],
      "malaria" => %w[malaria plasmodium],
      "paludismo" => %w[malaria plasmodium],
      "sifilis" => %w[syphilis],
      "hepatite" => %w[hepatitis],
      "carga" => %w[viral load],
      "viral" => %w[virus viral],
      "contagem" => %w[count],
      "velocidade" => %w[rate],
      "sedimentacao" => %w[sedimentation],
      "coagulacao" => %w[coagulation],
      "protrombina" => %w[prothrombin],
      "tipagem" => %w[type],
      "sanguinea" => %w[blood],
      "grupo" => %w[group],
      "anticorpo" => %w[antibody],
      "antigenio" => %w[antigen],
      "teste" => [],
      "rapido" => [],
      "total" => %w[total],
      "livre" => %w[free],
      "directa" => %w[direct],
      "indirecta" => %w[indirect]
    }.freeze

    # Words that appear in half the catalogue and narrow nothing.
    STOPWORDS = %w[the and for with test exame analise doseamento pesquisa determinacao].freeze

    def initialize(catalogue:, coverage: LoincCoverage.new)
      @catalogue = catalogue
      @coverage = coverage
    end

    def rows
      @rows ||= @coverage.uncovered.map do |entity_type, entry|
        candidates = @catalogue.search(tokens_for(entry), limit: CANDIDATES)

        [ entity_type, entry.national_code, entry.name, nil ] + candidate_columns(candidates)
      end
    end

    def with_candidates
      rows.count { |row| row[4].present? }
    end

    def write_csv(path = DEFAULT_PATH)
      full_path = Rails.root.join(path)
      FileUtils.mkdir_p(File.dirname(full_path))

      CSV.open(full_path, "w") do |csv|
        csv << HEADERS
        rows.each { |row| csv << row }
      end

      full_path
    end

    private

    def candidate_columns(candidates)
      Array.new(CANDIDATES) { |index| candidates[index] }
           .flat_map { |candidate| [ candidate&.code, candidate&.label ] }
    end

    # The entry's own words, translated where the glossary knows them and kept
    # where it does not — a name already in English, or a Latin organism name,
    # matches LOINC perfectly well untouched.
    def tokens_for(entry)
      words = normalise("#{entry.name} #{entry.short_name}")

      words.flat_map { |word| GLOSSARY.fetch(word, [ word ]) }
           .flat_map { |phrase| phrase.split(" ") }
           .uniq
           .reject { |token| token.length < 3 || STOPWORDS.include?(token) }
    end

    # Accents off, punctuation off. The catalogue spells the same word both ways
    # depending on who typed it in, and LOINC has no accents at all.
    def normalise(text)
      text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
          .downcase.split(/[^a-z0-9]+/).reject(&:blank?)
    end
  end
end
