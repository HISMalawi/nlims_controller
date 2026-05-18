# frozen_string_literal: true

# Phase 1: Add UUID columns to all transactional tables
# This migration adds UUID columns without populating them yet (zero downtime)
class AddUuidToTransactionalTables < ActiveRecord::Migration[7.1]
  def change
    # Add UUID columns to primary tables
    add_column :tests, :uuid, :string, limit: 36, after: :id
    add_column :specimen_status_trails, :uuid, :string, limit: 36, after: :id
    add_column :test_status_trails, :uuid, :string, limit: 36, after: :id
    add_column :test_results, :uuid, :string, limit: 36, after: :id

    # Add UUID foreign key columns for relationships
    # These will mirror the existing bigint foreign keys
    add_column :tests, :order_uuid, :string, limit: 36, after: :specimen_id
    add_column :specimen_status_trails, :order_uuid, :string, limit: 36, after: :specimen_id
    add_column :test_status_trails, :test_uuid, :string, limit: 36, after: :test_id
    add_column :test_results, :test_uuid, :string, limit: 36, after: :test_id
  end
end
