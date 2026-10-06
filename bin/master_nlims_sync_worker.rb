#!/usr/bin/env ruby
# frozen_string_literal: true

# Entry point for Master NLIMS Sync Data Worker
# This worker runs independently every 2 hours due to its heavy operations
# It syncs data from master NLIMS and pushes updates to EMR

NlimsWorker.start_master_nlims_sync_data_worker
