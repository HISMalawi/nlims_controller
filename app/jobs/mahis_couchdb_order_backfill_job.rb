# frozen_string_literal: true

class MahisCouchdbOrderBackfillJob
  include Sidekiq::Job
  sidekiq_options lock: :until_executed,
                  on_conflict: :reject

  def perform(limit = 100)
    {
      pending_orders: MahisCouchdb::OrderChangesService.new.process_all_pending_documents,
      sync_error_logs: MahisCouchdb::OrderBackfillService.new.call(limit:)
    }
  end
end
