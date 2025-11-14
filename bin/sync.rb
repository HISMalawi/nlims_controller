# frozen_string_literal: true

begin
  puts 'Synchronizing Test Catalog'
  SyncToNlimsService.synchronize_test_catalog if Config.local_nlims?
rescue StandardError => e
  puts "Error: #{e.message} ==> Synchronize Test Catalog"
end

begin
  puts 'Pushing Orders to NLIMS'
  SyncToNlimsService.push_order_to_nlims if Config.local_nlims?
rescue StandardError => e
  puts "Error: #{e.message} ==> Push Order to Master NLIMS"
end

begin
  puts 'Force Pushing Orders to NLIMS'
  SyncToNlimsService.force_sync_order_to_nlims if Config.local_nlims?
rescue StandardError => e
  puts "Error: #{e.message} ==> Force Push Order to Master NLIMS"
end

begin
  puts 'Pushing Order Updates to NLIMS'
  SyncToNlimsService.push_order_update_to_nlims
rescue StandardError => e
  puts "Error: #{e.message} ==> Push Order Update to Master NLIMS"
end

begin
  puts 'Pushing Status Updates to NLIMS'
  SyncToNlimsService.push_status_to_nlims
rescue StandardError => e
  puts "Error: #{e.message} ==> Push Status to Master NLIMS"
end

begin
  puts 'Pushing Results to NLIMS'
  SyncToNlimsService.push_result_to_nlims
rescue StandardError => e
  puts "Error: #{e.message} ==> Push Result to Master NLIMS"
end

begin
  puts 'Pushing Acknowledgements to NLIMS'
  SyncToNlimsService.push_acknwoledgement_to_master_nlims if Config.local_nlims?
rescue StandardError => e
  puts "Error: #{e.message} ==> Push Acknowledgement to Master NLIMS"
end
