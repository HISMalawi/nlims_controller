#!/bin/bash

# Uncomment the following line to set the bundle path to vendor/bundle instead of the system default - usually when multiple apps are using the same gems which could lead to version conflicts/ application crashes
# bundle config set --local path 'vendor/bundle'
rm Gemfile.lock && bundle install --local && bundle exec rails db:migrate && (
  bundle exec rake db:seed:specific\[seed_dispatcher_types.rb\] &&
  bundle exec rake db:seed:specific\[seed_test_results_recepient_types.rb\] &&
  bundle exec rake db:seed:specific\[seed_name_mappings.rb\] &&
  bundle exec rake db:seed:specific\[init_tracking_number.rb\] &&
  bundle exec rake db:seed:specific\[seed_additional_test_statuses.rb\] &&
  bundle exec rake db:seed:specific\[seed_roles.rb\] &&
  bundle exec rake db:seed:specific\[add_roles_to_users.rb\] &&
  bundle exec rake db:load_metadata &&
  bundle exec rails r bin/mlab/clear_sync_trackers.rb
)
bundle exec rails r bin/updater.rb && bash bin/add_cronjob.sh

# Update indexes and constraints in background to avoid long downtime during migration
# Logs will be written to log/uuid_backfill.log
echo "Starting Index and constraint update process in background..."
nohup bundle exec rake uuid:add_indexes > log/uuid_add_indexes.log 2>&1 &