# frozen_string_literal: true

# What an operator types into the box at the top of the orders screen.
#
# There is one box rather than three, because the person using it has one thing
# in front of them — a tube, a note, a name read down a telephone — and should
# not have to decide which kind of thing it is before they can look it up. The
# query tries all three at once; only the name is a prefix match, so the two
# identifiers stay exact and a mistyped digit finds nothing rather than
# something.
class OrderSearch
  PER_PAGE = 50

  # A name prefix shorter than this matches half the register and helps nobody.
  MINIMUM_NAME_PREFIX = 3

  attr_reader :term, :status, :facility, :from, :to, :page

  def initialize(params = {})
    params = params.to_h.symbolize_keys

    @term = params[:q].to_s.strip
    @status = params[:status].presence
    @facility = params[:facility].to_s.strip.upcase.presence
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])
    @page = [ params[:page].to_i, 1 ].max
  end

  def filtered?
    term.present? || status.present? || facility.present? || from.present? || to.present?
  end

  # A search for one tracking number should land on the sample, not on a list of
  # one. The controller uses this to redirect.
  def exact_match
    return nil unless TrackingNumber.matches?(normalized_term)

    Order.find_by(tracking_number: normalized_term)
  end

  def results
    @results ||= scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
  end

  def total
    @total ||= scope.count
  end

  def pages
    [ (total / PER_PAGE.to_f).ceil, 1 ].max
  end

  def last_page?
    page >= pages
  end

  private

  def scope
    relation = Order.joins(:patient)
                    .includes(:patient, :specimen_type, order_tests: :test_type)
                    .order(created_at: :desc, id: :desc)

    relation = apply_term(relation)
    relation = relation.where(status: status) if status.present?
    relation = relation.where(sending_facility_code: facility) if facility.present?
    relation = relation.where(created_at: from.beginning_of_day..) if from
    relation = relation.where(created_at: ..to.end_of_day) if to

    relation
  end

  def apply_term(relation)
    return relation if term.blank?

    conditions = [ "orders.tracking_number = :exact", "patients.national_id = :exact" ]
    bindings = { exact: normalized_term }

    if normalized_term.length >= MINIMUM_NAME_PREFIX
      conditions << "patients.name LIKE :prefix"
      bindings[:prefix] = "#{sanitize_like(term)}%"
    end

    relation.where(conditions.join(" OR "), **bindings)
  end

  # Tracking numbers and national identifiers are both stored upper-cased, and
  # both get written down in lower case.
  def normalized_term
    @normalized_term ||= term.upcase
  end

  def sanitize_like(value)
    ActiveRecord::Base.sanitize_sql_like(value)
  end

  def parse_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
