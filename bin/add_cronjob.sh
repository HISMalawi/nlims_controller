#!/bin/bash

#############################################
#  NLIMS + EMR CRON JOB CLEANER & INSTALLER
#############################################

echo "============================================"
echo "  STARTING NLIMS CRON CLEANUP & INSTALLATION"
echo "============================================"

# Backup current crontab
backup_file="$HOME/crontab_backup_$(date +%Y%m%d_%H%M%S).txt"
crontab -l 2>/dev/null > "$backup_file"
echo "Backup created: $backup_file"
echo

#############################################
#  SAFELY KILL ONLY NLIMS BACKGROUND JOBS
#############################################

echo "Stopping running NLIMS background jobs..."

# Only kill:
#  - scripts under bin/
#  - rake jobs containing master_nlims:
#  - rails runner commands from this app
PIDS=$(ps aux \
  | grep -E "/var/www/nlims_controller/bin|master_nlims:" \
  | grep -v grep \
  | awk '{print $2}')

if [ -n "$PIDS" ]; then
  echo "Killing the following PIDs:"
  echo "$PIDS"
  kill -9 $PIDS
else
  echo "No NLIMS jobs running."
fi

echo


#############################################
#  REMOVE OLD VERSIONS OF NLIMS JOBS
#############################################

echo "Cleaning old NLIMS cron jobs..."

patterns_to_remove=(
"/var/www/nlims_controller"
"/var/www/nlims_data_syncroniser"
"/var/www/html/iBLIS"
"master_nlims:"
)

current=$(crontab -l 2>/dev/null)

for pattern in "${patterns_to_remove[@]}"; do
  current=$(echo "$current" | grep -Fv "$pattern")
done

echo "$current" | crontab -
echo "Old cron jobs removed."
echo

#############################################
#  CLEAN UP STALE LOCKS
#############################################

echo "Cleaning up stale NLIMS cron job locks in /tmp..."
LOCK_DIR="/tmp"

rm -f "$LOCK_DIR/log_tracking_numbers.lock" \
      "$LOCK_DIR/sync_sh.lock" \
      "$LOCK_DIR/nlims_sync_data.lock" \
      "$LOCK_DIR/nlims_ack.lock" \
      "$LOCK_DIR/nlims_update_couch_id.lock"

echo "Stale locks removed (if they existed)."
echo


#############################################
#  DEFINE NEW CRON JOBS
#############################################

LOCK_DIR="/tmp"

cron_log_tracking_numbers="*/5 * * * * flock -n $LOCK_DIR/log_tracking_numbers.lock /bin/bash -l -c 'cd /var/www/nlims_controller && ./bin/log_tracking_numbers.sh --silent >> log/log_tracking_numbers.log 2>&1'"

cron_sync_sh="*/5 * * * * flock -n $LOCK_DIR/sync_sh.lock /bin/bash -l -c 'cd /var/www/nlims_controller && ./bin/sync.sh --silent >> log/sync.log 2>&1'"

cron_nlims_sync_data="0 */3 * * * flock -n $LOCK_DIR/nlims_sync_data.lock /bin/bash -l -c 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd /var/www/nlims_controller && rbenv local 3.2.0 && RAILS_ENV=development bundle exec rake master_nlims:sync_data --silent >> log/pull_from_master_nlims.log 2>&1'"

cron_nlims_ack="*/30 * * * * flock -n $LOCK_DIR/nlims_ack.lock /bin/bash -l -c 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd /var/www/nlims_controller && rbenv local 3.2.0 && RAILS_ENV=development bundle exec rake master_nlims:sync_local_nlims_acknowledge_results --silent >> log/pull_from_master_nlims.log 2>&1'"

cron_nlims_update_couch_id="0 * */5 * * flock -n $LOCK_DIR/nlims_update_couch_id.lock /bin/bash -l -c 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd /var/www/nlims_controller && rbenv local 3.2.0 && RAILS_ENV=development bundle exec rake master_nlims:update_order_source_couch_id --silent >> log/update_order_source_couch_id.log 2>&1'"

# EMR job (NO FLOCK!)
cron_emr="*/5 * * * * /bin/bash -l -c 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd /var/www/EMR-API && bin/rails runner -e production '\''bin/lab/sync_worker.rb'\'''"

cron_rm_stale_locks="0 3 * * 6 /bin/bash -l -c 'cd /var/www/nlims_controller && ./bin/clean_up_stale_lock.sh --silent >> log/clean_up_stale_lock.log 2>&1'"


#############################################
#  FUNCTION TO ADD A CRON JOB SAFELY
#############################################

add_job() {
  local job="$1"
  local current_cron=$(crontab -l 2>/dev/null)

  if echo "$current_cron" | grep -F "$job" >/dev/null; then
    echo "Already exists: $job"
  else
    echo -e "$current_cron\n$job" | crontab -
    echo "Added: $job"
  fi
}


#############################################
#  ADD NEW CRON JOBS
#############################################

echo "Adding new cron jobs..."

add_job "$cron_log_tracking_numbers"
add_job "$cron_sync_sh"
add_job "$cron_nlims_sync_data"
add_job "$cron_nlims_ack"
add_job "$cron_nlims_update_couch_id"
add_job "$cron_emr"
add_job "$cron_rm_stale_locks"

echo
echo "============================================"
echo "      NLIMS CRON INSTALLATION COMPLETE"
echo "============================================"
