#!/bin/bash
rm Gemfile.lock && bundle install --local && rails db:migrate && (
  rake db:seed:specific\[seed_dispatcher_types.rb\] &&
  rake db:seed:specific\[seed_test_results_recepient_types.rb\] &&
  rake db:seed:specific\[seed_name_mappings.rb\] &&
  rake db:seed:specific\[init_tracking_number.rb\]
)
rails r bin/updater.rb && bash bin/add_cronjob.sh

# Update couch IDs for order sources
echo "Updating order source couch IDs..."
nohup bundle exec rake master_nlims:update_order_source_couch_id > log/update_order_source_couch_id.log 2>&1 &