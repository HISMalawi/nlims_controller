# frozen_string_literal: true

require "net/http"

module Dictionary
  # Reads the dictionary out of the mLab API rather than out of its database.
  #
  # Answers the same methods as Dictionary::MlabSource, with the same shapes, so
  # Dictionary::MlabImporter cannot tell the two apart. This is the way in when
  # mLab is reachable over HTTP but its MySQL port is not, which is the normal
  # case now that the laboratories run mLab behind the API.
  #
  # Three differences from reading the database, all of them the API's own doing
  # and all worth knowing before choosing this source:
  #
  #   * The API hides paediatric and cancer tests, and the panels holding them.
  #     They are absent here too, so an import over a dictionary loaded from the
  #     database retires them.
  #   * An indicator arrives attached to the test that uses it, so an indicator
  #     attached to nothing never arrives at all.
  #   * A test whose department mLab has retired cannot be read in detail — the
  #     API answers 404 — so its indicators and organisms cannot be read either.
  #     Those tests are still imported, and named in #warnings, because dropping
  #     them would retire tests the laboratories are running today.
  #
  # Everything else comes across whole. Only live rows are returned: the API
  # scopes retired ones out on its own, which is why nothing here filters.
  class MlabApiSource
    # Raised for what the operator has to fix: no credentials, a refused login,
    # an answer that is not what the API promises.
    class Error < StandardError; end

    # A broken connection is a transport failure, and callers already rescue
    # this one by name.
    TransportError = NodeTransport::TransportError

    DEFAULT_URL = "http://127.0.0.1:8005"
    LOGIN_PATH = "/api/v1/auth/application_login"
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 60

    # mLab TestIndicatorType -> our indicator value_type. The same table the
    # database source uses, kept in one place so the two agree.
    VALUE_TYPES = MlabSource::VALUE_TYPES

    attr_reader :warnings

    def self.from_env
      base_url = ENV.fetch("MLAB_API_URL", DEFAULT_URL)

      new(transport: NodeTransport.new(base_url: base_url, api_key: token_from_env(base_url)), label: base_url)
    end

    # A token if one was issued, otherwise an application login. The token lasts
    # two hours, which is longer than an import takes.
    def self.token_from_env(base_url)
      token = ENV["MLAB_API_TOKEN"].presence
      return token if token

      username = ENV["MLAB_API_USER"].presence
      raise Error, "Set MLAB_API_TOKEN, or MLAB_API_USER and MLAB_API_PASSWORD, to read the mLab API." if username.nil?

      log_in(base_url, username, ENV["MLAB_API_PASSWORD"].to_s)
    end

    def self.log_in(base_url, username, password)
      uri = URI.join(base_url, LOGIN_PATH)

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = { username: username, password: password }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port,
                                 use_ssl: uri.scheme == "https",
                                 open_timeout: OPEN_TIMEOUT,
                                 read_timeout: READ_TIMEOUT) { |http| http.request(request) }

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "#{uri} refused the login for #{username}: #{response.code} #{response.body.to_s.truncate(200)}"
      end

      JSON.parse(response.body).dig("authorization", "token").presence ||
        raise(Error, "#{uri} answered a login with no token")
    rescue JSON::ParserError => e
      raise Error, "#{uri} did not answer with json: #{e.message}"
    rescue SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError => e
      raise Error, "#{uri} unreachable: #{e.class}: #{e.message}"
    end

    def initialize(transport:, label: nil)
      @transport = transport
      @label = label
      @warnings = []
    end

    def describe
      @label.presence || "mLab API"
    end

    # ---------- entities ----------

    def departments
      @departments ||= list("/api/v1/departments").map do |row|
        { id: row[:id], name: row[:name], code: row[:code] }
      end
    end

    def specimen_types
      @specimen_types ||= list("/api/v1/specimen").map do |row|
        { id: row[:id], name: row[:name], description: row[:description] }
      end
    end

    def drugs
      @drugs ||= list("/api/v1/drugs").map do |row|
        { id: row[:id], name: row[:name], short_name: row[:short_name] }
      end
    end

    def organisms
      @organisms ||= list("/api/v1/organisms").map do |row|
        { id: row[:id], name: row[:name], description: row[:description] }
      end
    end

    # There is no endpoint for the mapping table, so each organism is read for
    # the drugs it was tested against.
    def organism_drug_links
      @organism_drug_links ||= organisms.flat_map do |organism|
        detail = get("/api/v1/organisms/#{organism[:id]}")

        Array(detail[:drugs]).map { |drug| { organism_id: organism[:id], drug_id: drug[:id] } }
      end
    end

    def indicators
      @indicators ||= indicator_rows.map do |row|
        {
          id: row[:id],
          name: row[:name],
          unit: row[:unit],
          description: row[:description],
          value_type: VALUE_TYPES.fetch(row.dig(:test_indicator_type, :id), "Free Text")
        }
      end
    end

    def indicator_ranges
      @indicator_ranges ||= indicator_rows.flat_map { |row| Array(row[:indicator_ranges]) }.map do |range|
        {
          test_indicator_id: range[:test_indicator_id],
          min_age: range[:min_age],
          max_age: range[:max_age],
          sex: range[:sex],
          lower_range: range[:lower_range],
          upper_range: range[:upper_range],
          interpretation: range[:interpretation],
          value: range[:value]
        }
      end
    end

    def test_types
      @test_types ||= list("/api/v1/test_types", key: :test_types).map do |row|
        {
          id: row[:id],
          name: row[:name],
          short_name: row[:short_name],
          department_id: row[:department_id],
          sex: row[:sex],
          target_tat: turnaround(row[:expected_turn_around_time])
        }
      end
    end

    def test_type_indicator_links
      @test_type_indicator_links ||= details.flat_map do |detail|
        Array(detail[:indicators]).map { |row| { test_type_id: detail[:id], indicator_id: row[:id] } }
      end
    end

    # From the mapping endpoint rather than from each test, because this one
    # answers for the tests whose detail the API refuses as well.
    def test_type_specimen_links
      @test_type_specimen_links ||= list("/api/v1/specimen_test_type_mappings", paginate: true).map do |row|
        { test_type_id: row[:test_type_id], specimen_type_id: row[:specimen_id] }
      end
    end

    # A test carries its organisms by name only, so they are matched back
    # against the organism list. Names are unique in mLab, which is what makes
    # this safe; one that does not match is reported rather than guessed at.
    def test_type_organism_links
      @test_type_organism_links ||= details.flat_map do |detail|
        Array(detail[:organisms]).filter_map do |organism|
          id = organism_ids_by_name[normalise(organism[:name])]

          if id.nil?
            warn_about("o exame #{label_for(detail)} isola «#{organism[:name]}», que não consta da lista de organismos")
            next
          end

          { test_type_id: detail[:id], organism_id: id }
        end
      end
    end

    def test_panels
      @test_panels ||= list("/api/v1/test_panels").map do |row|
        { id: row[:id], name: row[:name], short_name: row[:short_name], description: row[:description] }
      end
    end

    def test_panel_test_type_links
      @test_panel_test_type_links ||= test_panels.flat_map do |panel|
        detail = get("/api/v1/test_panels/#{panel[:id]}")

        Array(detail[:test_types]).map { |row| { test_panel_id: panel[:id], test_type_id: row[:id] } }
      end
    end

    private

    # One request per test: indicators, their ranges and the organisms isolated
    # come no other way.
    def details
      @details ||= test_types.filter_map { |row| detail_for(row) }
    end

    # A test whose department has been retired cannot be read: the API looks the
    # department up under a scope that hides it and answers 404. Asking anyway
    # would only turn a known gap into a failed import.
    def detail_for(row)
      unless department_ids.include?(row[:department_id])
        warn_about("o exame #{row[:name]} (id=#{row[:id]}) pertence ao departamento #{row[:department_id]}, " \
                   "retirado no mLab: a API não devolve o seu detalhe, por isso fica sem indicadores nem organismos")
        return nil
      end

      get("/api/v1/test_types/#{row[:id]}")
    end

    # The same indicator is attached to several tests; the first one carries as
    # much as any other.
    def indicator_rows
      @indicator_rows ||= details.flat_map { |detail| Array(detail[:indicators]) }.uniq { |row| row[:id] }
    end

    def department_ids
      @department_ids ||= departments.map { |row| row[:id] }.to_set
    end

    def organism_ids_by_name
      @organism_ids_by_name ||= organisms.to_h { |row| [ normalise(row[:name]), row[:id] ] }
    end

    def turnaround(expected)
      return nil if expected.blank?

      "#{expected[:value]} #{expected[:unit]}".strip.presence
    end

    def label_for(detail)
      "#{detail[:name]} (id=#{detail[:id]})"
    end

    def normalise(name)
      name.to_s.strip.downcase
    end

    def warn_about(message)
      @warnings << message unless @warnings.include?(message)
    end

    # ---------- transport ----------

    # A collection, however the endpoint chooses to wrap it. Most answer a bare
    # array; the ones that paginate answer a page and are followed to the end,
    # because a half-read list would look to the importer like rows that have
    # gone away upstream.
    def list(path, key: nil, **params)
      body = get(path, params)
      return body if body.is_a?(Array)

      rows = page_of(body, key)
      meta = body[:meta] || {}

      while (next_page = meta[:next_page])
        body = get(path, params.merge(page: next_page))
        rows.concat(page_of(body, key))
        meta = body[:meta] || {}
      end

      rows
    end

    def page_of(body, key)
      rows = body[key || :data]
      raise Error, "the mLab API answered #{body.keys.inspect} where a collection was expected" if rows.nil?

      Array(rows)
    end

    def get(path, params = {})
      symbolize(@transport.get(path, params))
    end

    def symbolize(body)
      case body
      when Array then body.map { |row| symbolize(row) }
      when Hash then body.deep_symbolize_keys
      else body
      end
    end
  end
end
