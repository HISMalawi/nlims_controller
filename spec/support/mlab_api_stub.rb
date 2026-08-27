# frozen_string_literal: true

# Serves any mLab-shaped source — MlabFixtureSource, normally — the way the
# mLab API serves it, so Dictionary::MlabApiSource can be read back and held
# against the database source it stands in for.
#
# It answers NodeTransport#get, keeps string keys the way JSON arrives, and
# records every path asked for.
class MlabApiStub
  NotFound = Class.new(NodeTransport::TransportError)

  INDICATOR_TYPE_NAMES = {
    0 => "Auto Complete", 1 => "Free Text", 2 => "Numeric",
    3 => "Alpha Numeric", 4 => "Rich Text"
  }.freeze

  attr_reader :requests

  # hidden_departments: departments mLab has retired. The API leaves them out of
  # its listing and answers 404 for any test that belongs to one.
  # per_page: makes the mapping endpoint paginate, as it does when asked to.
  def initialize(source, hidden_departments: [], per_page: nil)
    @source = source
    @hidden = Array(hidden_departments)
    @per_page = per_page
    @requests = []
  end

  def get(path, params = {})
    @requests << path

    json(route(path, params))
  end

  def asked_for?(path)
    @requests.include?(path)
  end

  private

  def route(path, params)
    case path
    when "/api/v1/departments" then visible_departments
    when "/api/v1/specimen" then @source.specimen_types
    when "/api/v1/drugs" then @source.drugs
    when "/api/v1/organisms" then @source.organisms
    when "/api/v1/test_panels" then @source.test_panels
    when "/api/v1/test_types" then { test_types: @source.test_types.map { |row| test_type(row) }, meta: {} }
    when "/api/v1/specimen_test_type_mappings" then specimen_mappings(params)
    when %r{\A/api/v1/organisms/(\d+)\z} then organism_detail(Regexp.last_match(1).to_i)
    when %r{\A/api/v1/test_panels/(\d+)\z} then panel_detail(Regexp.last_match(1).to_i)
    when %r{\A/api/v1/test_types/(\d+)\z} then test_type_detail(Regexp.last_match(1).to_i)
    else raise NotFound, "#{path} answered 404"
    end
  end

  def visible_departments
    @source.departments.reject { |row| @hidden.include?(row[:id]) }
  end

  # What the index carries: the row itself, plus the turnaround time as its own
  # record.
  def test_type(row)
    value, unit = row[:target_tat].to_s.split(" ", 2)

    row.except(:target_tat).merge(
      expected_turn_around_time: value.nil? ? nil : { id: row[:id], value: value, unit: unit }
    )
  end

  def test_type_detail(id)
    row = find(@source.test_types, id) or raise NotFound, "/api/v1/test_types/#{id} answered 404"
    department = find(visible_departments, row[:department_id])

    # The API looks the department up under a scope that hides retired ones and
    # lets the lookup raise, which reaches the caller as a 404.
    raise NotFound, "/api/v1/test_types/#{id} answered 404" if department.nil?

    test_type(row).merge(
      department: department.slice(:id, :name),
      specimens: linked(@source.test_type_specimen_links, :test_type_id, id, :specimen_type_id)
        .map { |specimen| specimen.slice(:id, :name) },
      organisms: linked(@source.test_type_organism_links, :test_type_id, id, :organism_id)
        .map { |organism| organism.slice(:name, :description).merge(retired: 0) },
      indicators: indicators_of(id)
    )
  end

  def indicators_of(test_type_id)
    ids = @source.test_type_indicator_links.select { |link| link[:test_type_id] == test_type_id }
                 .map { |link| link[:indicator_id] }

    @source.indicators.select { |row| ids.include?(row[:id]) }.map do |row|
      type = row[:test_indicator_type]

      {
        id: row[:id],
        name: row[:name],
        test_indicator_type: { id: type, name: INDICATOR_TYPE_NAMES[type] },
        unit: row[:unit],
        description: row[:description],
        retired: 0,
        indicator_ranges: ranges_of(row[:id])
      }
    end
  end

  def ranges_of(indicator_id)
    @source.indicator_ranges.select { |range| range[:test_indicator_id] == indicator_id }
           .each_with_index.map { |range, index| range.merge(id: index + 1, retired: 0) }
  end

  def organism_detail(id)
    organism = find(@source.organisms, id) or raise NotFound, "/api/v1/organisms/#{id} answered 404"

    organism.merge(drugs: linked(@source.organism_drug_links, :organism_id, id, :drug_id)
                            .map { |drug| drug.slice(:id, :name, :short_name) })
  end

  def panel_detail(id)
    panel = find(@source.test_panels, id) or raise NotFound, "/api/v1/test_panels/#{id} answered 404"

    panel.merge(test_types: linked(@source.test_panel_test_type_links, :test_panel_id, id, :test_type_id)
                              .map { |test_type| test_type.slice(:id, :name, :short_name) })
  end

  def specimen_mappings(params)
    rows = @source.test_type_specimen_links.each_with_index.map do |link, index|
      { id: index + 1, test_type_id: link[:test_type_id], specimen_id: link[:specimen_type_id] }
    end

    return rows if @per_page.nil?

    page = params[:page].to_i.clamp(1, Float::INFINITY)
    pages = (rows.length / @per_page.to_f).ceil

    {
      data: rows[(page - 1) * @per_page, @per_page] || [],
      meta: { current_page: page, next_page: (page + 1 if page < pages), total_pages: pages }
    }
  end

  def linked(links, owner_key, owner_id, target_key)
    targets = links.select { |link| link[owner_key] == owner_id }.map { |link| link[target_key] }

    collection_for(target_key).select { |row| targets.include?(row[:id]) }
  end

  def collection_for(target_key)
    case target_key
    when :specimen_type_id then @source.specimen_types
    when :organism_id then @source.organisms
    when :drug_id then @source.drugs
    when :test_type_id then @source.test_types
    end
  end

  def find(rows, id)
    rows.find { |row| row[:id] == id }
  end

  def json(payload)
    JSON.parse(payload.to_json)
  end
end
