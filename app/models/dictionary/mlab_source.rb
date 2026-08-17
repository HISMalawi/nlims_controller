# frozen_string_literal: true

module Dictionary
  # Reads the dictionary out of a SISLAB/mLab database. Every method returns
  # plain hashes, so the importer never touches SQL and can be driven from a
  # fixture in tests.
  #
  # Only live rows are returned. mLab marks removals with retired/voided rather
  # than deleting, and the two columns are not used consistently, so each query
  # names the one that table actually uses.
  class MlabSource
    # mLab TestIndicatorType -> our indicator value_type
    VALUE_TYPES = {
      0 => "AutoComplete",
      1 => "Free Text",
      2 => "Numeric",
      3 => "AlphaNumeric",
      4 => "Rich Text"
    }.freeze

    def self.from_env
      new(
        host: ENV.fetch("MLAB_DB_HOST", "127.0.0.1"),
        port: ENV.fetch("MLAB_DB_PORT", 3306).to_i,
        username: ENV.fetch("MLAB_DB_USER", "root"),
        password: ENV.fetch("MLAB_DB_PASSWORD", ""),
        database: ENV.fetch("MLAB_DB_NAME", "mlab")
      )
    end

    def initialize(**connection_options)
      @connection_options = connection_options
    end

    def describe
      "#{@connection_options[:username]}@#{@connection_options[:host]}/#{@connection_options[:database]}"
    end

    def departments
      # mLab retires departments that its own live test types still point at
      # (Banco de Sangue, Biologia Molecular). Dropping them would orphan those
      # tests, so a department any live test depends on is kept.
      query(<<~SQL)
        SELECT id, name, code
        FROM departments
        WHERE retired IS NULL OR retired = 0
           OR id IN (SELECT department_id FROM test_types WHERE retired IS NULL OR retired = 0)
      SQL
    end

    def specimen_types
      query("SELECT id, name, description FROM specimen WHERE retired IS NULL OR retired = 0")
    end

    def drugs
      query("SELECT id, name, short_name FROM drugs WHERE retired IS NULL OR retired = 0")
    end

    def organisms
      query("SELECT id, name, description FROM organisms WHERE retired IS NULL OR retired = 0")
    end

    def organism_drug_links
      query(<<~SQL)
        SELECT organism_id, drug_id FROM drug_organism_mappings
        WHERE retired IS NULL OR retired = 0
      SQL
    end

    def indicators
      query(<<~SQL).each do |row|
        SELECT id, name, unit, description, test_indicator_type
        FROM test_indicators
        WHERE retired IS NULL OR retired = 0
      SQL
        row[:value_type] = VALUE_TYPES.fetch(row[:test_indicator_type], "Free Text")
      end
    end

    def indicator_ranges
      query(<<~SQL)
        SELECT test_indicator_id, min_age, max_age, sex, lower_range, upper_range, interpretation, value
        FROM test_indicator_ranges
        WHERE retired IS NULL OR retired = 0
      SQL
    end

    def test_types
      tats = query(<<~SQL).to_h { |row| [ row[:test_type_id], "#{row[:value]} #{row[:unit]}".strip ] }
        SELECT test_type_id, value, unit FROM expected_tats WHERE voided IS NULL OR voided = 0
      SQL

      query(<<~SQL).each do |row|
        SELECT id, name, short_name, department_id, sex
        FROM test_types
        WHERE retired IS NULL OR retired = 0
      SQL
        row[:target_tat] = tats[row[:id]]
      end
    end

    def test_type_indicator_links
      query(<<~SQL)
        SELECT test_types_id AS test_type_id, test_indicators_id AS indicator_id
        FROM test_type_indicator_mappings
        WHERE voided IS NULL OR voided = 0
      SQL
    end

    def test_type_specimen_links
      query(<<~SQL)
        SELECT test_type_id, specimen_id AS specimen_type_id
        FROM specimen_test_type_mappings
        WHERE retired IS NULL OR retired = 0
      SQL
    end

    def test_type_organism_links
      query(<<~SQL)
        SELECT test_type_id, organism_id FROM test_type_organism_mappings
        WHERE retired IS NULL OR retired = 0
      SQL
    end

    def test_panels
      query("SELECT id, name, short_name, description FROM test_panels WHERE retired IS NULL OR retired = 0")
    end

    def test_panel_test_type_links
      query(<<~SQL)
        SELECT test_panel_id, test_type_id FROM test_type_panel_mappings
        WHERE voided IS NULL OR voided = 0
      SQL
    end

    private

    def connection
      @connection ||= Mysql2::Client.new(**@connection_options, encoding: "utf8mb4")
    end

    def query(sql)
      connection.query(sql, symbolize_keys: true).to_a
    end
  end
end
