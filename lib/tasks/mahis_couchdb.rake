# frozen_string_literal: true

namespace :mahis_couchdb do
  desc 'Start the permanent MaHIS CouchDB patients_records live listener'
  task listen: :environment do
    listener = MahisCouchdb::LiveChangesListener.new
    main_thread = Thread.main

    %w[INT TERM].each do |signal|
      trap(signal) do
        listener.request_stop
        main_thread.raise(Interrupt)
      end
    end

    begin
      listener.start
    rescue Interrupt
      listener.request_stop
    end
  end

  desc 'Process MaHIS CouchDB patients_records changes once, then exit'
  task sync_once: :environment do
    puts MahisCouchdb::OrderChangesService.new.call.inspect
  end
end
