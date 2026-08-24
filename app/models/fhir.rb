# frozen_string_literal: true

# The FHIR R4 façade: the same orders, samples and readings the rest of the API
# serves, in the shape an EMR already knows how to read.
#
# Nothing here owns any data. Every resource is projected from the transactional
# models, and every write goes back through OrderRequest — the intake that
# validates dictionary codes and expands panels — so there is one set of rules
# about what an order is, not one for each dialect that asks for one.
#
# The mapping tables below are the whole of the translation. They are constants
# rather than case statements so that a status this node grows and forgets to
# map fails loudly in one place instead of quietly becoming "unknown" on the
# wire.
module Fhir
  VERSION = "4.0.1"

  # The canonical base for every identifier, code system and profile this node
  # publishes. Overridable because a deployment behind a different hostname must
  # be able to publish URLs that resolve, but the default is the national one:
  # two nodes inventing two systems for the same national code is exactly the
  # ambiguity a code system exists to remove.
  def self.base_url
    @base_url ||= ENV.fetch("FHIR_BASE_URL", "https://sislab.misau.gov.mz/fhir").chomp("/")
  end

  # Deliberately not named `system`: that is Kernel#system, and a module method
  # shadowing it reads as a shell call to every static analyser and every person
  # who has ever debugged one.
  def self.url(path)
    "#{base_url}/#{path}"
  end

  def self.reset!
    @base_url = nil
  end

  # Identifier systems. A tracking number and a national patient identifier are
  # the two things a person can read off a tube and a card, and they are what an
  # EMR searches by.
  def self.tracking_number_system = url("sid/tracking-number")
  def self.national_id_system     = url("sid/patient-national-id")
  def self.placer_system          = url("sid/placer-order-number")

  # Code systems. LOINC is the interoperable one and is emitted wherever the
  # dictionary has been curated; the MOZ system is what this country actually
  # runs on and is always present, so a report is never uncodeable.
  LOINC_SYSTEM = "http://loinc.org"

  def self.code_system(entity_type) = url("CodeSystem/#{entity_type.to_s.tr('_', '-')}")

  # Where a native status is carried that FHIR's own value set cannot express.
  # An order refused by the laboratory and an order cancelled at the clinic are
  # both `revoked` to FHIR, and telling them apart is the difference between
  # drawing a second sample and not.
  def self.order_status_extension = url("StructureDefinition/order-status")
  def self.test_status_extension  = url("StructureDefinition/test-status")
  def self.revision_extension     = url("StructureDefinition/revision")

  # Order -> ServiceRequest.status. Everything before a terminal state is
  # `active`: FHIR has no vocabulary for "the sample is in the laboratory", and
  # inventing one by abusing `on-hold` would mislead every client that reads it.
  # The native status rides along in an extension for the ones that care.
  ORDER_STATUS = {
    Order::REQUESTED => "active",
    Order::ACCEPTED => "active",
    Order::SPECIMEN_COLLECTED => "active",
    Order::IN_PROGRESS => "active",
    Order::REFERRED_OUT => "active",
    Order::REFERRED_IN => "active",
    Order::COMPLETED => "completed",
    Order::REJECTED => "revoked",
    Order::CANCELLED => "revoked"
  }.freeze

  # Order -> ServiceRequest.intent. Always `order`: an EMR asking for a test is
  # an authorisation to perform it, not a proposal.
  INTENT = "order"

  ORDER_PRIORITY = {
    "routine" => "routine",
    "urgent" => "urgent",
    "stat" => "stat"
  }.freeze

  # OrderTest -> DiagnosticReport.status. `registered` means the request is
  # known but nothing has been observed; `partial` that work has begun.
  TEST_STATUS = {
    OrderTest::PENDING => "registered",
    OrderTest::IN_PROGRESS => "partial",
    OrderTest::COMPLETED => "final",
    OrderTest::REJECTED => "cancelled",
    OrderTest::CANCELLED => "cancelled"
  }.freeze

  # Order -> Specimen.status. A rejected sample is exactly FHIR's
  # `unsatisfactory`, which is the one place the two vocabularies agree exactly.
  SPECIMEN_STATUS = {
    Order::REJECTED => "unsatisfactory",
    Order::CANCELLED => "entered-in-error"
  }.freeze
  SPECIMEN_STATUS_DEFAULT = "available"

  SEX = {
    "F" => "female",
    "M" => "male",
    "Unknown" => "unknown"
  }.freeze

  # The reverse, for intake. FHIR's `other` has no home in a three-value column
  # and becomes Unknown rather than being refused: an EMR should not fail to
  # raise an order over a demographic field.
  ADMINISTRATIVE_GENDER = {
    "female" => "F",
    "male" => "M",
    "other" => "Unknown",
    "unknown" => "Unknown"
  }.freeze

  PRIORITY_FROM_FHIR = {
    "routine" => "routine",
    "urgent" => "urgent",
    "asap" => "urgent",
    "stat" => "stat"
  }.freeze
end
