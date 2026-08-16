# frozen_string_literal: true

# The schema was created with a mix of latin1 and utf8mb3 tables. A latin1 column cannot hold the
# accented test/specimen/patient names this deployment works with, and joining a latin1 column
# against a utf8mb3 one raises "Illegal mix of collations". Align everything on the database
# default (utf8mb3_uca1400_ai_ci).
class ConvertLatin1TablesToUtf8 < ActiveRecord::Migration[7.1]
  COLLATION = 'utf8mb3_uca1400_ai_ci'

  # Rails' own bookkeeping tables (schema_migrations, ar_internal_metadata) are left alone.
  TABLES = %w[
    data_anomalies
    drug_susceptibilities
    drugs
    measure_ranges
    measure_types
    organism_drugs
    organisms
    panel_types
    panels
    patients
    referrals
    rejection_reasons
    remarks
    site_sync_frequencies
    sites
    specimen
    specimen_dispatch_types
    specimen_dispatches
    specimen_status_trails
    test_categories
    test_organisms
    test_panels
    test_phases
    test_result_recepient_types
    test_results
    test_status_trails
    tests
    testtype_organisms
    users
    visit_types
    visits
    visittype_wards
  ].freeze

  def up
    convert_to('utf8mb3', COLLATION)
  end

  def down
    convert_to('latin1', 'latin1_swedish_ci')
  end

  private

  def convert_to(charset, collation)
    TABLES.each do |table|
      next unless table_exists?(table)

      execute "ALTER TABLE `#{table}` CONVERT TO CHARACTER SET #{charset} COLLATE #{collation}"
    end
  end
end
