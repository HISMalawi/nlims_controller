# frozen_string_literal: true

module Fhir
  # Turning what an EMR posted into orders.
  #
  # This class only reads FHIR and writes the payload OrderRequest already
  # takes. It deliberately validates nothing about tests, panels or dictionary
  # codes: that judgement lives in OrderRequest, is the same judgement the JSON
  # intake gets, and duplicating it here is how the two dialects would start
  # disagreeing about what an order is.
  #
  # Two shapes are accepted, because an EMR has two honest ways to say this:
  #
  #   POST /fhir/r4/ServiceRequest   one test on one sample
  #   POST /fhir/r4                  a transaction Bundle, several tests on one
  #                                  sample, grouped by `requisition`
  class OrderIntake
    SERVICE_REQUEST = "ServiceRequest"
    PATIENT = "Patient"
    SPECIMEN = "Specimen"
    BUNDLE = "Bundle"

    # A code written without a system, which happens. The prefixes are the
    # dictionary's own and are unambiguous, so a client that sends a bare
    # MOZ-TT- code is understood rather than refused on a technicality.
    TEST_TYPE_CODE = /\AMOZ-TT-/
    TEST_PANEL_CODE = /\AMOZ-TP-/
    SPECIMEN_TYPE_CODE = /\AMOZ-SP-/

    class << self
      # Every order the posted resource asks for, created. A list even for the
      # single-resource case, so the caller has one thing to render.
      def call!(resource, api_client:)
        resource = (resource || {}).deep_symbolize_keys

        case resource[:resourceType]
        when SERVICE_REQUEST then [ new([ resource ], resource, api_client: api_client).create! ]
        when BUNDLE then from_bundle(resource, api_client: api_client)
        else
          raise InvalidRequest.new(
            "esperava um ServiceRequest ou um Bundle de transacção, recebi #{resource[:resourceType].inspect}",
            field: "resourceType"
          )
        end
      end

      private

      # One order per requisition. That is what the identifier means — the tests
      # that travel on one tube — and it is the only thing in the bundle that
      # can say which of several tests belong together.
      def from_bundle(bundle, api_client:)
        requests = entries_of(bundle, SERVICE_REQUEST)

        if requests.empty?
          raise InvalidRequest.new("o Bundle não contém nenhum ServiceRequest", field: "Bundle.entry")
        end

        requests.group_by { |request| request.dig(:requisition, :value) }
                .values
                .map { |group| new(group, bundle, api_client: api_client).create! }
      end

      def entries_of(bundle, type)
        Array(bundle[:entry]).filter_map do |entry|
          resource = entry[:resource]
          resource if resource.is_a?(Hash) && resource[:resourceType] == type
        end
      end
    end

    # `scope` is where referenced resources are looked for: the bundle for a
    # transaction, the resource's own `contained` for a bare ServiceRequest.
    def initialize(service_requests, scope, api_client:)
      @service_requests = service_requests
      @scope = scope
      @api_client = api_client
    end

    def create!
      OrderRequest.new(payload, api_client: @api_client).create!
    end

    # The identifier the EMR gave this request, if it gave one. Used as the
    # idempotency key when the client sent no header: a placer order number is
    # already the thing that makes a retry recognisable as a retry.
    def self.placer_identifier(resource)
      resource = (resource || {}).deep_symbolize_keys
      candidates =
        case resource[:resourceType]
        when BUNDLE then Array(resource[:entry]).filter_map { |entry| entry[:resource] }
        else [ resource ]
        end

      candidates.filter_map { |candidate| Array(candidate[:identifier]).first&.dig(:value) }.first.presence
    end

    private

    def leader
      @leader ||= @service_requests.first
    end

    def payload
      {
        patient: patient_payload,
        order: order_payload,
        tests: @service_requests.map { |request| test_payload(request) }
      }
    end

    # ---------------------------------------------------------------- patient

    def patient_payload
      resource = patient_resource

      if resource.nil?
        raise InvalidRequest.new(
          "não encontrei o doente: inclua um Patient em `contained` ou no Bundle, " \
          "ou refira um já conhecido por `subject.identifier`",
          field: "ServiceRequest.subject"
        )
      end

      {
        national_id: identifier_value(resource[:identifier], Fhir.national_id_system),
        name: human_name(resource),
        sex: Fhir::ADMINISTRATIVE_GENDER.fetch(resource[:gender].to_s, "Unknown"),
        birthdate: resource[:birthDate],
        phone: telecom_value(resource[:telecom], "phone")
      }.compact
    end

    # A Patient the request carried, or one this node already has. Looking the
    # known patient up rather than trusting the reference is deliberate:
    # OrderRequest matches on the national identifier anyway, so what is needed
    # here is the demographics, and an EMR that references a patient by uuid
    # should not have to repeat them.
    def patient_resource
      inline = referenced(leader.dig(:subject, :reference), PATIENT)
      return inline if inline

      known = known_patient
      return if known.nil?

      {
        identifier: [ { system: Fhir.national_id_system, value: known.national_id } ],
        name: [ { text: known.name } ],
        gender: Fhir::SEX[known.sex],
        birthDate: known.birthdate&.iso8601,
        telecom: known.phone && [ { system: "phone", value: known.phone } ]
      }.compact
    end

    def known_patient
      subject = leader[:subject] || {}
      uuid = subject[:reference].to_s[%r{\APatient/(.+)\z}, 1]
      return Patient.find_by(uuid: uuid) if uuid.present?

      national_id = subject.dig(:identifier, :value)
      return if national_id.blank?

      Patient.find_by(national_id: Patient.normalize_value_for(:national_id, national_id))
    end

    # `text` is what this system stores, so it is preferred where the EMR sent
    # it. Otherwise the parts are joined in the order FHIR writes them, which is
    # the order a Mozambican name is written in too.
    def human_name(resource)
      name = Array(resource[:name]).first || {}
      return name[:text] if name[:text].present?

      [ Array(name[:given]).join(" ").presence, name[:family].presence ].compact.join(" ").presence
    end

    # ------------------------------------------------------------------ order

    def order_payload
      specimen = specimen_resource || {}

      {
        sending_facility_code: @api_client&.facility_code,
        receiving_lab_code: receiving_lab_code,
        priority: Fhir::PRIORITY_FROM_FHIR[leader[:priority].to_s],
        requested_by: leader.dig(:requester, :display),
        order_location: Array(leader[:locationCode]).first&.dig(:text),
        clinical_history: Array(leader[:note]).first&.dig(:text),
        collected_at: specimen.dig(:collection, :collectedDateTime),
        specimen_type: national_reference(specimen[:type], "specimen_types", SpecimenType)
      }.compact
    end

    # Which laboratory is being asked, when the requester names one. FHIR has no
    # better place for it than `performer`.
    #
    # Optional, and usually absent. A ServiceRequest comes from a clinician, who
    # is asking the health facility for a test rather than assigning a bench;
    # the sample arrives at the unit unclaimed and the laboratory that takes it
    # is the one that runs it.
    def receiving_lab_code
      code = Array(leader[:performer]).filter_map { |performer| performer.dig(:identifier, :value) }.first
      code = Array(leader[:performer]).filter_map { |performer| performer[:display] }.first if code.blank?
      code.presence
    end

    def specimen_resource
      referenced(Array(leader[:specimen]).first&.dig(:reference), SPECIMEN)
    end

    # ------------------------------------------------------------------ tests

    def test_payload(request)
      concept = request[:code]
      test = { method_of_testing: Array(request[:orderDetail]).first&.dig(:text) }.compact

      # Panels before types at each step, never across steps. A concept that
      # names a national test type outright must not be answered by a panel that
      # happens to share its LOINC code — the explicit statement wins over the
      # inferred one, whichever kind it turns out to be.
      reference = resolve_test(concept)
      return test.merge(reference) if reference

      raise InvalidRequest.new(
        "o pedido não diz que exame é: indique um código do sistema " \
        "#{Fhir.code_system('test_types')}, um código LOINC já mapeado neste nó, ou ao menos um nome",
        field: "ServiceRequest.code"
      )
    end

    # What exam this is. A code this node's catalogue carries names an entry; a
    # code it does not, or no code at all, is carried through under whatever the
    # concept was written with. The display text is what a laboratory reads off
    # the request, and while the national catalogue is being assembled it is
    # often the only thing that identifies the exam at all.
    def resolve_test(concept)
      return unless concept.is_a?(Hash)

      codings = Array(concept[:coding])
      name = concept_name(concept)

      resolved = panel_first(
        ->(entity_type, _model) { explicit_code(codings, entity_type) },
        ->(_entity_type, model) { loinc_code(codings, model) },
        ->(entity_type, _model) { bare_code(codings, entity_type) }
      )
      return resolved.transform_values { |reference| reference.merge(name: name).compact } if resolved

      code = codings.filter_map { |coding| coding[:code].presence }.first
      return if code.blank? && name.blank?

      { test_type: { national_code: code, name: name }.compact }
    end

    # Each strategy tried for a panel and then for a test type before the next
    # is reached.
    def panel_first(*strategies)
      strategies.each do |strategy|
        code = strategy.call("test_panels", TestPanel)
        return { test_panel: { national_code: code } } if code.present?

        code = strategy.call("test_types", TestType)
        return { test_type: { national_code: code } } if code.present?
      end

      nil
    end

    # How a CodeableConcept says, in words, what it is: the concept's own text,
    # or the first display any of its codings carries.
    def concept_name(concept)
      concept[:text].presence || Array(concept[:coding]).filter_map { |coding| coding[:display].presence }.first
    end

    # ------------------------------------------------------------ terminology

    # A CodeableConcept turned into the `{ national_code: }` reference the rest
    # of the system speaks.
    def national_reference(concept, entity_type, model)
      return unless concept.is_a?(Hash)

      codings = Array(concept[:coding])
      code = explicit_code(codings, entity_type) || loinc_code(codings, model) || bare_code(codings, entity_type)
      code = codings.filter_map { |coding| coding[:code].presence }.first if code.blank?
      name = concept_name(concept)
      return if code.blank? && name.blank?

      { national_code: code, name: name }.compact
    end

    def explicit_code(codings, entity_type)
      codings.find { |coding| coding[:system] == Fhir.code_system(entity_type) }&.dig(:code).presence
    end

    # LOINC is only usable where somebody has curated it into the dictionary. An
    # uncurated code is not an error here — it simply does not identify anything
    # on this node, and the caller says so with the field name.
    def loinc_code(codings, model)
      return if model.nil?

      loinc = codings.find { |coding| coding[:system] == Fhir::LOINC_SYSTEM }&.dig(:code)
      return if loinc.blank?

      model.active.find_by(loinc_code: loinc)&.national_code
    end

    # A code written without a system, which happens. The dictionary's prefixes
    # are unambiguous, so a client that sends a bare MOZ-TT- code is understood
    # rather than refused on a technicality.
    def bare_code(codings, entity_type)
      pattern = case entity_type
      when "test_types" then TEST_TYPE_CODE
      when "test_panels" then TEST_PANEL_CODE
      when "specimen_types" then SPECIMEN_TYPE_CODE
      end
      return if pattern.nil?

      codings.filter_map { |coding| coding[:code] }.find { |value| pattern.match?(value.to_s) }
    end

    # --------------------------------------------------------------- plumbing

    # Follows `#local` into `contained`, and a `Type/id` into the bundle the
    # request arrived in. No other reference is followed: fetching a resource
    # from wherever a client points is how a façade becomes an open proxy.
    def referenced(reference, type)
      reference = reference.to_s
      return contained(reference.delete_prefix("#"), type) if reference.start_with?("#")

      # A transaction Bundle carries the patient and the specimen as entries of
      # their own; a bare ServiceRequest carries them in `contained`. Neither is
      # addressed by anything this node would have to go and fetch.
      bundled(type) || contained(nil, type)
    end

    def contained(id, type)
      Array(leader[:contained]).find do |resource|
        resource[:resourceType] == type && (id.blank? || resource[:id].to_s == id)
      end
    end

    def bundled(type)
      return unless @scope[:resourceType] == BUNDLE

      Array(@scope[:entry]).filter_map { |entry| entry[:resource] }
                           .find { |resource| resource[:resourceType] == type }
    end

    def identifier_value(identifiers, system)
      list = Array(identifiers)
      list.find { |identifier| identifier[:system] == system }&.dig(:value).presence ||
        list.first&.dig(:value).presence
    end

    def telecom_value(telecoms, system)
      Array(telecoms).find { |telecom| telecom[:system] == system }&.dig(:value)
    end
  end
end
