#!/bin/bash
rails db:migrate && (
  rake db:seed:specific\[seed_dispatcher_types.rb\] &&
  rake db:seed:specific\[seed_test_results_recepient_types.rb\] &&
  rake db:seed:specific\[seed_update_site_name.rb\] &&
  rake db:seed:specific\[seed_update_sites.rb\] &&
  rake db:seed:specific\[seed_name_mappings.rb\] &&
  rake db:seed:specific\[init_tracking_number.rb\]
)