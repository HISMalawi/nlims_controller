#!/bin/bash

# This script is used to add a cron job to the current user's crontab.
# It first removes a specific cron job if it exists, and then adds a new one.

cron_jobs_to_remove=('0 */2 * * * export PATH="$HOME/.rbenv/bin:$PATH" && eval "$(rbenv init -)" && cd /var/www/nlims_controller && rbenv local 2.5.3 && RAILS_ENV=development bundle exec rake master_nlims:sync_data --silent >> log/pull_from_master_nlims.log 2>&1'
"0 */2 * * * /bin/bash -l -c 'cd /var/www/nlims_controller && rbenv local 2.5.3 && RAILS_ENV=development bundle exec rake master_nlims:sync_data --silent >> log/pull_from_master_nlims.log 2>&1'"
"*/2 * * * * /bin/bash -l -c 'cd /var/www/nlims_data_syncroniser/ && rbenv local 2.5.3 && RAILS_ENV=development bundle exec rake nlims:sync_from_couchdb_to_couchdb --silent >> log/sync_couchdb_to_couchdb.log 2>&1'"
)
latest_current_cron_jobs=$(crontab -l 2>/dev/null)

for job in "${cron_jobs_to_remove[@]}"; do
  latest_current_cron_jobs=$(echo "$latest_current_cron_jobs" | grep -Fv "$job")
done

# Install the new crontab (without the target job)
echo "$latest_current_cron_jobs" | crontab -

# Define the cron job to add
sync_cron_job="*/5 * * * * /bin/bash -l -c 'cd /var/www/nlims_controller && ./bin/sync.sh --silent >> log/sync.log 2>&1'"
cron_job="*/5 * * * * /bin/bash -l -c 'cd /var/www/nlims_controller && ./bin/log_tracking_numbers.sh --silent >> log/log_tracking_numbers.log 2>&1'"
emr_cron_job="*/5 * * * * /bin/bash -l -c 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd /var/www/EMR-API && bin/rails runner -e production '\''bin/lab/sync_worker.rb'\'''"


# Get the current list of cron jobs
current_cron_jobs=$(crontab -l 2>/dev/null)

# Check if the cron job already exists
if echo "$current_cron_jobs" | grep -F "$cron_job" >/dev/null; then
    echo "Cron job already exists."
else
    # Append the new cron job if it doesn't exist
    echo -e "$current_cron_jobs\n$cron_job" | crontab -
    echo "Cron job added successfully!"
fi

current_cron_jobs=$(crontab -l 2>/dev/null)
if echo "$current_cron_jobs" | grep -F "$sync_cron_job" >/dev/null; then
    echo "Cron job already exists."
else
    # Append the new cron job if it doesn't exist
    echo -e "$current_cron_jobs\n$sync_cron_job" | crontab -
    echo "Cron job added successfully!"
fi

current_cron_jobs=$(crontab -l 2>/dev/null)
if echo "$current_cron_jobs" | grep -F "$emr_cron_job" >/dev/null; then
    echo "Cron job already exists."
else
    # Append the new cron job if it doesn't exist
    echo -e "$current_cron_jobs\n$emr_cron_job" | crontab -
    echo "Cron job added successfully!"
fi

current_cron_jobs=$(crontab -l 2>/dev/null)
nlims_cron_job="0 */3 * * * /bin/bash -l -c 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd /var/www/nlims_controller && rbenv local 3.2.0 && RAILS_ENV=development bundle exec rake master_nlims:sync_data --silent >> log/pull_from_master_nlims.log 2>&1'"
if echo "$current_cron_jobs" | grep -F "$nlims_cron_job" >/dev/null; then
    echo "Cron job already exists."
else
    # Append the new cron job if it doesn't exist
    echo -e "$current_cron_jobs\n$nlims_cron_job" | crontab -
    echo "Cron job added successfully!"
fi
