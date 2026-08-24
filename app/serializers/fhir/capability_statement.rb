# frozen_string_literal: true

module Fhir
  # What this node can do, in the only form a FHIR client will look for it.
  #
  # This is the FHIR façade's contract, the way docs/sislab-sync/openapi.yaml is
  # the JSON API's. It is generated rather than written down so that it cannot
  # describe a search parameter no controller reads: everything declared here is
  # a constant the code branches on, or a route the router actually has.
  class CapabilityStatement
    TYPE = "CapabilityStatement"

    # Search parameters every resource that hangs off an order understands. They
    # are the same three questions in each case — which sample, whose, and what
    # state — so they are declared once.
    COMMON_SEARCH = [
      { name: "identifier", type: "token",
        documentation: "O número de seguimento (tracking number) escrito no tubo." },
      { name: "patient", type: "reference",
        documentation: "`Patient/{uuid}` ou o uuid do doente." },
      { name: "patient.identifier", type: "token",
        documentation: "O identificador nacional do doente." },
      { name: "_count", type: "number", documentation: "Máximo de recursos por bundle (1–500, por omissão 100)." }
    ].freeze

    def self.call(base_url:) = new(base_url: base_url).as_json

    def initialize(base_url:)
      @base_url = base_url
    end

    def as_json
      {
        resourceType: TYPE,
        id: "sislab-sync",
        url: "#{@base_url}/metadata",
        version: SislabSync.version,
        name: "SislabSyncEmrFacade",
        title: "SISLAB Sync — fachada FHIR R4 para o EMR",
        status: "active",
        date: Date.current.iso8601,
        publisher: "MISAU — Ministério da Saúde de Moçambique",
        kind: "instance",
        software: { name: "SISLAB Sync", version: SislabSync.version },
        implementation: { description: "Nó #{SislabSync.node_code}", url: @base_url },
        fhirVersion: Fhir::VERSION,
        format: [ "application/fhir+json", "json" ],
        rest: [ rest ]
      }
    end

    private

    def rest
      {
        mode: "server",
        documentation: documentation,
        security: security,
        resource: [ service_request, diagnostic_report, observation, patient, specimen ],
        interaction: [ { code: "transaction",
                         documentation: "POST na raiz, com um Bundle `transaction`: um Patient, um Specimen e " \
                                        "um ServiceRequest por teste, agrupados por `requisition`. Cria uma " \
                                        "única ordem com todos os testes, ou nenhuma." } ],
        operation: [
          { name: "acknowledge", definition: Fhir.url("OperationDefinition/Observation-acknowledge"),
            documentation: "POST Observation/{id}/$acknowledge — confirma que o EMR arquivou a leitura. " \
                           "Recusado com 409 se a leitura já tiver sido substituída por uma correcção." }
        ]
      }
    end

    def documentation
      <<~TEXT.strip
        Os códigos são emitidos em dois sistemas: o código nacional
        (#{Fhir.code_system('test_types')} e equivalentes), sempre presente, e
        LOINC, presente apenas onde o dicionário já foi curado. Um pedido pode
        chegar em qualquer dos dois.

        Os estados nativos deste sistema viajam em extensões
        (#{Fhir.order_status_extension}, #{Fhir.test_status_extension}) porque o
        vocabulário do FHIR não os distingue: uma amostra recusada pelo
        laboratório e um pedido cancelado na consulta são ambos `revoked`.
      TEXT
    end

    # One scheme, no OAuth dance. The integrations run unattended and a token
    # that expires overnight is an outage.
    def security
      {
        cors: false,
        service: [ {
          coding: [ { system: "http://terminology.hl7.org/CodeSystem/restful-security-service", code: "Basic" } ],
          text: "Bearer <chave de API> no cabeçalho Authorization"
        } ]
      }
    end

    def service_request
      {
        type: "ServiceRequest",
        profile: "http://hl7.org/fhir/StructureDefinition/ServiceRequest",
        documentation: "Um ServiceRequest é um teste. Os testes de uma mesma amostra partilham " \
                       "`requisition`, que é o número de seguimento. Um código de painel expande-se " \
                       "nos testes que o compõem, e a resposta é então um Bundle `collection`.",
        interaction: [ { code: "create" }, { code: "read" }, { code: "search-type" } ],
        searchParam: COMMON_SEARCH + [
          { name: "requisition", type: "token", documentation: "O número de seguimento do grupo de testes." },
          { name: "status", type: "token",
            documentation: "Estado FHIR: #{Fhir::ORDER_STATUS.values.uniq.join(', ')}." }
        ]
      }
    end

    def diagnostic_report
      {
        type: "DiagnosticReport",
        profile: "http://hl7.org/fhir/StructureDefinition/DiagnosticReport",
        documentation: "Um relatório por teste, com as leituras actuais em `contained`. " \
                       "`corrected` significa que uma leitura foi substituída depois de o teste " \
                       "ter terminado — o teste não reabre.",
        interaction: [ { code: "read" }, { code: "search-type" } ],
        searchParam: COMMON_SEARCH + [
          { name: "status", type: "token",
            documentation: "Estado FHIR: #{Fhir::TEST_STATUS.values.uniq.join(', ')}." }
        ]
      }
    end

    def observation
      {
        type: "Observation",
        profile: "http://hl7.org/fhir/StructureDefinition/Observation",
        documentation: "O feed de resultados. `_since` é uma revisão de um contador com bloqueio, " \
                       "não uma data: siga o link `next` do bundle até não haver, guarde a última " \
                       "revisão e recomece daí. Correcções viajam no mesmo feed, com estado " \
                       "`entered-in-error` e a extensão `replaced-by`.",
        interaction: [ { code: "read" }, { code: "search-type" } ],
        searchParam: COMMON_SEARCH + [
          { name: "_since", type: "number",
            documentation: "Cursor de revisão. Devolve tudo o que mudou depois desta revisão." }
        ]
      }
    end

    def patient
      {
        type: "Patient",
        profile: "http://hl7.org/fhir/StructureDefinition/Patient",
        documentation: "Só doentes com amostras nesta unidade sanitária. A pesquisa exige " \
                       "`identifier`: este nó não é um registo de doentes.",
        interaction: [ { code: "read" }, { code: "search-type" } ],
        searchParam: [ { name: "identifier", type: "token", documentation: "O identificador nacional do doente." } ]
      }
    end

    def specimen
      {
        type: "Specimen",
        profile: "http://hl7.org/fhir/StructureDefinition/Specimen",
        documentation: "A amostra, com o mesmo uuid da ordem: aqui uma ordem é uma amostra.",
        interaction: [ { code: "read" } ]
      }
    end
  end
end
