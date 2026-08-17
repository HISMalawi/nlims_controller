# frozen_string_literal: true

module OrdersHelper
  # An order and a test on it have separate state machines and separate
  # vocabularies, and the history mixes both. The entity type on the event says
  # which set of words to read it with.
  def history_scope(event)
    event.entity_type == "orders" ? "orders.statuses" : "order_tests.statuses"
  end

  # Age is what a clinician reads; the birthdate is what is stored. Whole years
  # only — a laboratory reference range for a paediatric indicator is by year,
  # and anything finer would suggest a precision the birthdate rarely has.
  def patient_age(patient)
    return nil if patient.birthdate.blank?

    t("patients.age", years: ((Date.current - patient.birthdate) / 365.25).floor)
  end
end
