#!/bin/bash
rm Gemfile.lock && bundle install --local && bundle exec rails db:migrate && (
  bundle exec rake db:seed:specific\[seed_dispatcher_types.rb\] &&
  bundle exec rake db:seed:specific\[seed_test_results_recepient_types.rb\] &&
  bundle exec rake db:seed:specific\[seed_name_mappings.rb\] &&
  bundle exec rake db:seed:specific\[init_tracking_number.rb\]
)
bundle exec rails r bin/updater.rb && bash bin/add_cronjob.sh

# Update couch IDs for order sources
echo "Updating order source couch IDs..."
nohup bundle exec rake master_nlims:update_order_source_couch_id > log/update_order_source_couch_id.log 2>&1 &