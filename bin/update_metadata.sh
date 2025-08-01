#!/bin/bash
bundle install --local && rails db:migrate && (
  rake db:seed:specific\[seed_dispatcher_types.rb\] &&
  rake db:seed:specific\[seed_test_results_recepient_types.rb\] &&
  rake db:seed:specific\[seed_name_mappings.rb\] &&
  rake db:seed:specific\[init_tracking_number.rb\]
)
rails r bin/updater.rb