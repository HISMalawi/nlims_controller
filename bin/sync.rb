# frozen_string_literal: true

begin
  SyncToNlimsService.synchronize_test_catalog
rescue StandardError => e
  puts "Error: #{e.message} ==> Synchronize Test Catalog"
end

begin
  SyncToNlimsService.push_order_to_nlims if Config.local_nlims?
rescue StandardError => e
  puts "Error: #{e.message} ==> Push Order to Master NLIMS"
end

begin
  SyncToNlimsService.push_order_update_to_nlims
rescue StandardError => e
  puts "Error: #{e.message} ==> Push Order Update to Master NLIMS"
end

begin
  SyncToNlimsService.push_status_to_nlims
rescue StandardError => e
  puts "Error: #{e.message} ==> Push Status to Master NLIMS"
end

begin
  SyncToNlimsService.push_result_to_nlims
rescue StandardError => e
  puts "Error: #{e.message} ==> Push Result to Master NLIMS"
end

begin
  SyncToNlimsService.push_acknwoledgement_to_master_nlims if Config.local_nlims?
rescue StandardError => e
  puts "Error: #{e.message} ==> Push Acknowledgement to Master NLIMS"
end
