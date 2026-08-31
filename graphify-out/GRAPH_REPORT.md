# Graph Report - nlims_controller  (2026-08-31)

## Corpus Check
- 333 files · ~398,530 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1998 nodes · 2838 edges · 260 communities (176 shown, 84 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 254 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `aae346ed`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- InboundEvent
- ApiKey
- DictionaryEntriesController
- SislabSyncClient::Connection
- Fhir::OrderIntake
- ApiContract::Operation
- Api::BaseController
- Dictionary::MlabApiSource
- Dictionary::MlabImporter
- Sync::Applier
- ApplicationRecord
- Dictionary::Applier
- Dictionary::LoincCatalogue
- Fhir::ServiceRequestResource
- Referral
- seeds.rb
- Dictionary::QualityReport
- DictionaryEntry
- Dictionary::Serializer
- .authorize_scope!
- Dictionary::MlabSource
- Api::V3::Lab::ReferralsController
- MlabApiStub
- .api_client
- Fhir::CapabilityStatement
- OutboxEvent
- Api::V3::ResultsController
- .post
- OrderRequest
- .token_value
- OrderSearch
- NodeStatus
- Dictionary::LoincMapping
- TestResult
- .auth_headers
- Fhir::ObservationResource
- ApplicationController
- Api::V3::Lab::OrdersController
- .render_resource
- Sequence
- SislabSyncClient::Emr
- SislabSyncClient::Lab
- SISLAB Sync OpenAPI 3.1 contract
- sislab_sync.rb
- Fhir::ObservationsController
- Order
- Dictionary::LoincCoverage
- app service (Puma)
- .from_env
- .render_api_error
- Api::V3::Sync::InboundController
- sync_outbox
- .create
- Patient
- reference.rb
- Fhir
- StatusEvent
- Fhir::DiagnosticReportResource
- SISLAB Sync v2 rebuild plan
- Dictionary::SnapshotSource
- Authentication
- Fhir::ServiceRequestsController
- UiHelper
- Dictionary::Reference
- TracksStatus
- reference_client_spec.rb
- inbound_spec.rb
- Session
- Fhir::BaseController
- Dictionary::LoincSuggestions
- Api::Errors
- TestType
- SislabSyncClient::Feed
- MlabFixtureSource
- RecordedInbound
- .create
- sislab_sync_client reference gem
- OrderTest
- Fhir::Bundle
- Fhir::CodeableConcept
- SislabSyncClient::Profile
- Current
- Api::V3::NodesController
- .examine
- Sync::Heartbeat
- Sync::Pull
- Sync::Push
- Fhir::PatientResource
- National laboratory registry (labs)
- reports_spec.rb
- recorded_feed.rb
- StatusMachine
- SislabSyncClient::Node
- API error messages (en)
- lab/referrals_spec.rb
- service_requests_spec.rb
- Api::V3::HealthController
- Api::V3::OrderRequestsController
- DictionaryController
- NavigationHelper
- Dictionary::Puller
- Lab
- Lab client profile
- moz_catalog.rake
- Application Icon (Solid Red Circle, 512x512 PNG)
- Dictionary::Promotion
- Dictionary::Link
- tracking_number.rb
- CreateDictionaryEntities
- National dictionary and its synchronisation
- observations_spec.rb
- OrdersHelper
- Dictionary::Seed
- clear_the_node
- OrderSerializer
- SislabSync
- CreateSequences
- v3/dictionary_spec.rb
- SignInHelpers
- ApplicationMailer
- Sync::Routing
- DictionaryReference
- CreateApiClients
- CreateApiKeys
- CreateRequestAudits
- CreateIdempotentRequests
- CreateDictionaryLinks
- CreateExternalMappings
- CreateDictionaryStatusChanges
- CreateSyncCursors
- CreateDictionaryLinkDeferrals
- CreatePatients
- CreateOrders
- CreateOrderTests
- CreateTestResults
- CreateStatusEvents
- AddCursorAndAcknowledgementToTestResults
- AddCursorAndClaimToOrders
- CreateRejectionReasons
- CreateSyncOutbox
- CreateInboundEvents
- CreateNodes
- CreateReferrals
- CreateInboundDeliveries
- CreateUsers
- CreateLabs
- RelaxDictionaryReferences
- Application Icon (512x512 Red Circle)
- application_helper.rb
- controllers/application.js
- dev
- docker-entrypoint
- version.rb
- 400 Bad Request static page
- 404 Not Found static page
- SyncCursor
- .show
- ReferralsController
- SessionsController
- OrdersController
- clear_the_node
- outbox_event.rb
- OrdersArriveAtAFacility
- order_requests_spec.rb
- Api
- DictionaryTerms
- CreateFacilities
- CLAUDE.md

## God Nodes (most connected - your core abstractions)
1. `ApplicationRecord` - 43 edges
2. `Order` - 36 edges
3. `Dictionary::MlabApiSource` - 33 edges
4. `Referral` - 32 edges
5. `OutboxEvent` - 31 edges
6. `DictionaryEntry` - 29 edges
7. `NodeStatus` - 29 edges
8. `Dictionary::MlabImporter` - 28 edges
9. `Fhir::OrderIntake` - 28 edges
10. `TestResult` - 26 edges

## Surprising Connections (you probably didn't know these)
- `Client-side Idempotency-Key` --semantically_similar_to--> `At-least-once delivery with idempotency`  [INFERRED] [semantically similar]
  clients/ruby/README.md → docs/sislab-sync/plano.html
- `Monotonic revision cursor` --semantically_similar_to--> `FHIR results feed by revision cursor`  [INFERRED] [semantically similar]
  docs/sislab-sync/plano.html → README.md
- `CI spec job` --semantically_similar_to--> `mysql service (MySQL 8.4)`  [INFERRED] [semantically similar]
  .github/workflows/ci.yml → docker-compose.yml
- `500 Internal Server Error static page` --semantically_similar_to--> `API error messages (en)`  [AMBIGUOUS] [semantically similar]
  public/500.html → config/locales/en.yml
- `each_page cursor paging` --semantically_similar_to--> `FHIR results feed by revision cursor`  [INFERRED] [semantically similar]
  clients/ruby/README.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **One artefact, two modes** — readme_dual_mode, readme_sislab_sync_mode_env, docs_sislab_sync_openapi_x_node_mode, _github_workflows_ci_mode_matrix, docker_compose_project_name, config_database_default, readme_production_deployment [INFERRED 0.85]
- **Outbox replication guarantees** — docs_sislab_sync_plano_sync_outbox, docs_sislab_sync_plano_at_least_once, docs_sislab_sync_plano_order_per_aggregate, docs_sislab_sync_plano_national_never_initiates, docs_sislab_sync_openapi_pushevents, docs_sislab_sync_openapi_inboundevents, docs_sislab_sync_openapi_heartbeat, clients_ruby_readme_node_profile [INFERRED 0.85]
- **Browser and Install Icon Surface** — public_icon_app_icon, public_icon_pwa_manifest_icon_slot, public_icon_favicon_and_apple_touch_icon_slot, public_icon_single_asset_serves_every_icon_role [INFERRED 0.85]
- **Revision cursor discipline across surfaces** — docs_sislab_sync_plano_revision_cursor, docs_sislab_sync_openapi_cursor_pagination, readme_fhir_results_feed, clients_ruby_readme_cursor_paging, config_database_read_committed [INFERRED 0.85]

## Communities (260 total, 84 thin omitted)

### Community 0 - "InboundEvent"
Cohesion: 0.13
Nodes (4): InboundEvent, Sync, Sync::Ingest, Sync::Ingest::Result

### Community 1 - "ApiKey"
Cohesion: 0.05
Nodes (12): ApiClientsController, ApiKeysController, AuditsController, ApiClient, ApiKey, authenticate(), digest(), environment_segment() (+4 more)

### Community 2 - "DictionaryEntriesController"
Cohesion: 0.12
Nodes (4): DictionaryEntriesController, Dictionary, Dictionary::Editable, Dictionary::Editable::Field

### Community 3 - "SislabSyncClient::Connection"
Cohesion: 0.07
Nodes (21): SislabSyncClient, SislabSyncClient::Connection, SislabSyncClient::Response, StandardError, SislabSyncClient, SislabSyncClient::Conflict, SislabSyncClient::Error, SislabSyncClient::FeedStalled (+13 more)

### Community 4 - "Fhir::OrderIntake"
Cohesion: 0.06
Nodes (9): AddedTests, call!(), entries_of(), Fhir, Fhir::OrderIntake, from_bundle(), InvalidRequest, StandardError (+1 more)

### Community 5 - "ApiContract::Operation"
Cohesion: 0.08
Nodes (19): ApiContract, ApiContract::Operation, expand(), operation_for(), operations(), resolve(), runs_here?(), this_node() (+11 more)

### Community 6 - "Api::BaseController"
Cohesion: 0.20
Nodes (4): Api, Api::BaseController, Api, Api::Auditing

### Community 7 - "Dictionary::MlabApiSource"
Cohesion: 0.06
Nodes (7): Dictionary, Dictionary::MlabApiSource, Dictionary::MlabApiSource::Error, StandardError, NodeTransport, NodeTransport::TransportError, StandardError

### Community 8 - "Dictionary::MlabImporter"
Cohesion: 0.12
Nodes (6): Dictionary, Dictionary::MlabImporter, ExternalMapping, import_the_dictionary(), print_skipped(), print_warnings()

### Community 9 - "Sync::Applier"
Cohesion: 0.12
Nodes (5): Sync, Sync::Applier, StandardError, Sync, Sync::Rejected

### Community 10 - "ApplicationRecord"
Cohesion: 0.06
Nodes (15): ApplicationRecord, Base, BumpsOwnerRevision, Drug, IndicatorRange, Node, OrganismDrug, Organism (+7 more)

### Community 11 - "Dictionary::Applier"
Cohesion: 0.09
Nodes (8): Dictionary, Dictionary::Applier, DictionaryLinkDeferral, DictionaryStatusChange, LabsBelongToFacilities, wipe_dictionary!(), cursor(), wipe_dictionary!()

### Community 12 - "Dictionary::LoincCatalogue"
Cohesion: 0.10
Nodes (7): Dictionary, Dictionary::LoincCatalogue, Dictionary::LoincCatalogue::Entry, Dictionary::LoincCatalogue::MissingFile, StandardError, load_catalogue(), LoincFixture

### Community 13 - "Fhir::ServiceRequestResource"
Cohesion: 0.10
Nodes (4): Fhir, Fhir::ServiceRequestResource, Fhir, Fhir::SpecimenResource

### Community 14 - "Referral"
Cohesion: 0.13
Nodes (4): StandardError, Referral, Referral::AlreadySettled, dispatch_referral()

### Community 15 - "seeds.rb"
Cohesion: 0.16
Nodes (21): Department, SpecimenType, api_client(), call(), dictionary(), indicator(), national_catalogue(), nodes() (+13 more)

### Community 16 - "Dictionary::QualityReport"
Cohesion: 0.13
Nodes (4): Dictionary, Dictionary::QualityReport, Dictionary::QualityReport::Issue, Indicator

### Community 17 - "DictionaryEntry"
Cohesion: 0.13
Nodes (3): DictionaryEntry, DictionaryEntry::Withdrawn, StandardError

### Community 18 - "Dictionary::Serializer"
Cohesion: 0.09
Nodes (10): changes_since(), cursor(), delta(), Dictionary, Dictionary::UnknownEntity, model_for(), model_for!(), StandardError (+2 more)

### Community 19 - ".authorize_scope!"
Cohesion: 0.19
Nodes (4): Api::V3::OrdersController, BaseController, BaseController, SpecProbeController

### Community 21 - "Api::V3::Lab::ReferralsController"
Cohesion: 0.12
Nodes (7): Api, Api::V3, Api::V3::Lab, Api::V3::Lab::ReferralsController, BaseController, Api, Api::Authentication

### Community 22 - "MlabApiStub"
Cohesion: 0.19
Nodes (3): MlabApiStub, MlabApiStub::NotFound, TransportError

### Community 23 - ".api_client"
Cohesion: 0.27
Nodes (3): Api, Api::Idempotency, IdempotentRequest

### Community 24 - "Fhir::CapabilityStatement"
Cohesion: 0.11
Nodes (5): Fhir, Fhir::CapabilityController, BaseController, Fhir, Fhir::CapabilityStatement

### Community 25 - "OutboxEvent"
Cohesion: 0.12
Nodes (3): SyncQueueController, OutboxEvent, OutboxEvent::Backoff

### Community 26 - "Api::V3::ResultsController"
Cohesion: 0.08
Nodes (7): Api, Api::V3, Api::V3::ResultsController, BaseController, OrderTestSerializer, PatientSerializer, TestResultSerializer

### Community 27 - ".post"
Cohesion: 0.13
Nodes (4): add_tests(), beat(), post_events(), RecordingNationalNode

### Community 29 - ".token_value"
Cohesion: 0.33
Nodes (3): Fhir, Fhir::DiagnosticReportsController, BaseController

### Community 32 - "Dictionary::LoincMapping"
Cohesion: 0.14
Nodes (5): Dictionary, Dictionary::LoincMapping, Dictionary::LoincMapping::InvalidFile, Dictionary::LoincMapping::Outcome, StandardError

### Community 34 - ".auth_headers"
Cohesion: 0.14
Nodes (9): post_probe(), patch_status(), claim(), get_pending(), get_order(), get_results(), acknowledge(), get_results() (+1 more)

### Community 36 - "ApplicationController"
Cohesion: 0.15
Nodes (5): ApiDocsController, ApplicationController, Base, DashboardController, NodesController

### Community 37 - "Api::V3::Lab::OrdersController"
Cohesion: 0.12
Nodes (5): Api, Api::V3, Api::V3::Lab, Api::V3::Lab::OrdersController, BaseController

### Community 38 - ".render_resource"
Cohesion: 0.13
Nodes (3): Fhir, Fhir::SpecimensController, BaseController

### Community 39 - "Sequence"
Cohesion: 0.17
Nodes (3): StandardError, Sequence, Sequence::NotInTransaction

### Community 40 - "SislabSyncClient::Emr"
Cohesion: 0.15
Nodes (5): Profile, SislabSyncClient, SislabSyncClient::Emr, emr(), SislabSyncClient

### Community 41 - "SislabSyncClient::Lab"
Cohesion: 0.20
Nodes (3): Profile, SislabSyncClient, SislabSyncClient::Lab

### Community 42 - "SISLAB Sync OpenAPI 3.1 contract"
Cohesion: 0.17
Nodes (16): each_page cursor paging, Emr client profile, Client-side Idempotency-Key, Clinical term resolution policy, SISLAB Sync OpenAPI 3.1 contract, createOrderRequest operation, Cursor pagination (since / next_cursor / has_more), Duplicate /api/v3/results path entry (+8 more)

### Community 43 - "sislab_sync.rb"
Cohesion: 0.10
Nodes (10): Facility, facility(), fetch_facility_code(), labs(), local?(), national?(), StandardError, SislabSync (+2 more)

### Community 44 - "Fhir::ObservationsController"
Cohesion: 0.24
Nodes (3): Fhir, Fhir::ObservationsController, BaseController

### Community 45 - "Order"
Cohesion: 0.16
Nodes (4): Order, Order::AlreadyClaimed, StandardError, TrackingNumber

### Community 46 - "Dictionary::LoincCoverage"
Cohesion: 0.19
Nodes (3): Dictionary, Dictionary::LoincCoverage, Dictionary::LoincCoverage::Row

### Community 47 - "app service (Puma)"
Cohesion: 0.16
Nodes (14): Dual-mode CI matrix, CI spec job, Swappable Transport, Database default connection (env-driven), READ-COMMITTED transaction isolation, TEST_DATABASE_NAME separation, app service (Puma), css service (Tailwind watcher) (+6 more)

### Community 48 - ".from_env"
Cohesion: 0.12
Nodes (5): ApplicationJob, Base, DictionaryPullJob, SyncPullJob, SyncPushJob

### Community 49 - ".render_api_error"
Cohesion: 0.12
Nodes (9): Api, Api::V3, Api::V3::DictionaryController, BaseController, Api, Api::V3, Api::V3::Sync, Api::V3::Sync::EventsController (+1 more)

### Community 50 - "Api::V3::Sync::InboundController"
Cohesion: 0.19
Nodes (5): Api, Api::V3, Api::V3::Sync, Api::V3::Sync::InboundController, BaseController

### Community 51 - "sync_outbox"
Cohesion: 0.19
Nodes (13): Node client profile, Action Cable Redis adapter (production), Sidekiq queue weights, redis service (Redis 7), sidekiq service, heartbeat operation, inboundEvents operation, pushEvents operation (+5 more)

### Community 52 - ".create"
Cohesion: 0.22
Nodes (3): Fhir, Fhir::TransactionsController, BaseController

### Community 53 - "Patient"
Cohesion: 0.18
Nodes (4): Fhir, Fhir::PatientsController, BaseController, Patient

### Community 54 - "reference.rb"
Cohesion: 0.39
Nodes (7): by_code(), by_name(), by_uuid(), coerce(), lookup(), resolve(), resolve!()

### Community 58 - "SISLAB Sync v2 rebuild plan"
Cohesion: 0.18
Nodes (12): data/meta/errors response envelope, x-node-mode operation availability, draft → active promotion gate, Fixed decisions register, The national node never initiates a connection, SISLAB Sync v2 rebuild plan, Monotonic revision cursor, Risk register and mitigations (+4 more)

### Community 59 - "Dictionary::SnapshotSource"
Cohesion: 0.22
Nodes (4): Dictionary, Dictionary::SnapshotSource, Dictionary::SnapshotSource::Missing, StandardError

### Community 61 - "Fhir::ServiceRequestsController"
Cohesion: 0.29
Nodes (3): Fhir, Fhir::ServiceRequestsController, BaseController

### Community 65 - "reference_client_spec.rb"
Cohesion: 0.20
Nodes (3): lab_profile(), profile_for(), RackTransport

### Community 66 - "inbound_spec.rb"
Cohesion: 0.22
Nodes (5): get_inbound(), push_from(), specimen_type(), test_type(), ApiKeyHelpers

### Community 68 - "Fhir::BaseController"
Cohesion: 0.25
Nodes (3): Fhir, Fhir::BaseController, BaseController

### Community 70 - "Api::Errors"
Cohesion: 0.20
Nodes (4): Api, Api::Errors, Fhir, Fhir::OperationOutcome

### Community 71 - "TestType"
Cohesion: 0.20
Nodes (4): TestType, build_dictionary!(), describe_test_type(), create_published()

### Community 72 - "SislabSyncClient::Feed"
Cohesion: 0.27
Nodes (3): SislabSyncClient, SislabSyncClient::Feed, enum_for()

### Community 73 - "MlabFixtureSource"
Cohesion: 0.24
Nodes (3): SnapshotSource, seed(), MlabFixtureSource

### Community 74 - "RecordedInbound"
Cohesion: 0.20
Nodes (3): feed(), BrokenInbound, RecordedInbound

### Community 75 - ".create"
Cohesion: 0.17
Nodes (8): sample_in_progress(), event(), indicator(), lab_registered(), order_created(), specimen_type(), test_type(), failing_event()

### Community 76 - "sislab_sync_client reference gem"
Cohesion: 0.22
Nodes (9): CI lint job, RuboCop configuration (omakase + rspec), Relaxed RSpec cops, me as the first diagnostic call, Zero runtime dependencies by design, sislab_sync_client reference gem, bundler-audit ignore list, The twelve steps S1–S12 (+1 more)

### Community 81 - "Current"
Cohesion: 0.22
Nodes (4): Api, Api::RateLimiting, Current, CurrentAttributes

### Community 82 - "Api::V3::NodesController"
Cohesion: 0.29
Nodes (4): Api, Api::V3, Api::V3::NodesController, BaseController

### Community 88 - "National laboratory registry (labs)"
Cohesion: 0.32
Nodes (8): Session and authorisation messages (pt), Portuguese locale (default UI language), API key carries node identity, API key format ssk_<env>_<prefix>_<secret>, 406 Unsupported Browser static page, API key scopes, National laboratory registry (labs), Web management interface

### Community 89 - "reports_spec.rb"
Cohesion: 0.36
Nodes (6): indicator(), order_test(), patch_status(), post_rejection(), post_results(), send_json()

### Community 90 - "recorded_feed.rb"
Cohesion: 0.25
Nodes (3): BrokenFeed, EndlessFeed, RecordedFeed

### Community 92 - "SislabSyncClient::Node"
Cohesion: 0.29
Nodes (3): Profile, SislabSyncClient, SislabSyncClient::Node

### Community 93 - "API error messages (en)"
Cohesion: 0.33
Nodes (7): One exception class per refusal, Automatic RateLimited retry, API error messages (en), English locale, ErrorCode enum, 422 Unprocessable Entity static page, 500 Internal Server Error static page

### Community 94 - "lab/referrals_spec.rb"
Cohesion: 0.38
Nodes (6): in_progress_order(), refer(), referral(), referred_order(), send_json(), settle()

### Community 95 - "service_requests_spec.rb"
Cohesion: 0.38
Nodes (5): api_client(), bundle(), headers(), post_request(), single_request()

### Community 96 - "Api::V3::HealthController"
Cohesion: 0.33
Nodes (4): Api, Api::V3, Api::V3::HealthController, BaseController

### Community 97 - "Api::V3::OrderRequestsController"
Cohesion: 0.33
Nodes (4): Api, Api::V3, Api::V3::OrderRequestsController, BaseController

### Community 102 - "Lab client profile"
Cohesion: 0.33
Nodes (6): Lab client profile, Corrections via replaced_by_uuid, Tracking number format, Transactional core schema, Native statuses in FHIR extensions, SISLAB_SYNC_LAB_CODE

### Community 104 - "Application Icon (Solid Red Circle, 512x512 PNG)"
Cohesion: 0.60
Nodes (6): Application Icon (Solid Red Circle, 512x512 PNG), Favicon and Apple Touch Icon Slot, Flat Geometry Scales Without Detail Loss, Placeholder Brand Mark, PWA Manifest Icon Slot, One Raster Asset Serves Every Icon Role

### Community 107 - "tracking_number.rb"
Cohesion: 0.60
Nodes (3): day_stamp(), facility(), generate()

### Community 109 - "National dictionary and its synchronisation"
Cohesion: 0.50
Nodes (5): dictionaryChanges operation, external_mappings table, dictionary:seed initial catalogue load, National dictionary and its synchronisation, mLab import (database and API paths)

### Community 113 - "Dictionary::Seed"
Cohesion: 0.20
Nodes (3): Dictionary, Dictionary::Seed, RejectionReason

### Community 114 - "clear_the_node"
Cohesion: 0.24
Nodes (8): InboundDelivery, as_the_national_node(), clear_the_node(), inbound_for(), outbox_wire(), raise_order_at(), rebuild_the_national_node(), replay()

### Community 115 - "OrderSerializer"
Cohesion: 0.17
Nodes (3): OrderSerializer, ReferralSerializer, StatusEventSerializer

### Community 116 - "SislabSync"
Cohesion: 0.50
Nodes (3): Application, SislabSync, SislabSync::Application

### Community 149 - "Application Icon (512x512 Red Circle)"
Cohesion: 0.67
Nodes (3): Application Icon (512x512 Red Circle), Placeholder Branding Asset, Static Public Asset Serving

### Community 248 - ".show"
Cohesion: 0.33
Nodes (4): Api, Api::V3, Api::V3::MeController, BaseController

### Community 255 - "order_requests_spec.rb"
Cohesion: 0.83
Nodes (3): payload(), post_from_lab(), post_order()

## Ambiguous Edges - Review These
- `Flat Geometry Scales Without Detail Loss` → `Placeholder Brand Mark`  [AMBIGUOUS]
  public/icon.png · relation: conceptually_related_to
- `Duplicate /api/v3/results path entry` → `listResults operation`  [AMBIGUOUS]
  docs/sislab-sync/openapi.yaml · relation: references
- `Assumptions and out of scope` → `SISLAB_SYNC_TLS_TERMINATED`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `API error messages (en)` → `500 Internal Server Error static page`  [AMBIGUOUS]
  public/500.html · relation: semantically_similar_to

## Knowledge Gaps
- **27 isolated node(s):** `ApplicationHelper`, `application`, `Dictionary`, `SislabSyncClient`, `SislabSyncClient` (+22 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **84 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Flat Geometry Scales Without Detail Loss` and `Placeholder Brand Mark`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Duplicate /api/v3/results path entry` and `listResults operation`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Assumptions and out of scope` and `SISLAB_SYNC_TLS_TERMINATED`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `API error messages (en)` and `500 Internal Server Error static page`?**
  _Edge tagged AMBIGUOUS (relation: semantically_similar_to) - confidence is low._
- **Why does `ApplicationRecord` connect `ApplicationRecord` to `InboundEvent`, `ApiKey`, `Dictionary::MlabImporter`, `Dictionary::Applier`, `Referral`, `seeds.rb`, `Dictionary::QualityReport`, `.api_client`, `OutboxEvent`, `Dictionary::LoincMapping`, `TestResult`, `Sequence`, `sislab_sync.rb`, `Order`, `Patient`, `StatusEvent`, `Session`, `TestType`, `OrderTest`, `Lab`, `Dictionary::Promotion`, `Dictionary::Seed`, `clear_the_node`, `SyncCursor`?**
  _High betweenness centrality (0.170) - this node is a cross-community bridge._
- **Why does `Order` connect `Order` to `DictionaryTerms`, `Fhir::OrderIntake`, `Sync::Applier`, `ApplicationRecord`, `seeds.rb`, `.authorize_scope!`, `OrderRequest`, `OrderSearch`, `NodeStatus`, `ApplicationController`, `Api::V3::Lab::OrdersController`, `.render_resource`, `Sequence`, `Patient`, `StatusEvent`, `TracksStatus`, `OrderTest`, `clear_the_node`, `Sync::Routing`, `OrdersController`, `clear_the_node`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **Why does `lab_profile()` connect `reference_client_spec.rb` to `inbound_spec.rb`, `.create`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._