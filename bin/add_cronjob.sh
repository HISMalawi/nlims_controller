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
#  CLEAN UP OLD LOCKS
#############################################

echo "Cleaning up old NLIMS cron job locks in /tmp..."
LOCK_DIR="/tmp"

# Remove old flock-based locks (no longer used)
rm -f "$LOCK_DIR/log_tracking_numbers.lock" \
      "$LOCK_DIR/sync_sh.lock" \
      "$LOCK_DIR/nlims_sync_data.lock" \
      "$LOCK_DIR/nlims_ack.lock" \
      "$LOCK_DIR/nlims_update_couch_id.lock"

echo "Old locks removed (if they existed)."
echo


#############################################
#  DEFINE NEW CRON JOBS (WORKER-BASED)
#############################################

# New unified worker system - runs every 5 minutes
# All NLIMS sync tasks are handled by workers that run in parallel with file-based locking
cron_nlims_worker="*/15 * * * * /bin/bash -l -c 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd /var/www/nlims_controller && rbenv local 3.2.0 && DISABLE_SPRING=1 RAILS_ENV=development bin/rails runner bin/worker.rb >> log/nlims_worker.log 2>&1'"

# Master NLIMS sync data worker - runs every 2 hours (heavier operation)
cron_master_nlims_sync="0 */2 * * * /bin/bash -l -c 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd /var/www/nlims_controller && rbenv local 3.2.0 && DISABLE_SPRING=1 RAILS_ENV=development bin/rails runner bin/master_nlims_sync_worker.rb >> log/workers/master_nlims_sync_data_worker.log 2>&1'"

# Note: Update order source couch ID job moved to config/schedule.yml (Sidekiq Cron)
# Runs weekly on Friday at 3pm via Sidekiq scheduler

# EMR job (runs independently)
cron_emr="*/5 * * * * /bin/bash -l -c 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd /var/www/EMR-API && bin/rails runner -e production '\''bin/lab/sync_worker.rb'\'''"

# Clean up stale worker locks weekly
cron_rm_stale_locks="0 3 * * 6 /bin/bash -l -c 'cd /var/www/nlims_controller && ./bin/clean_up_worker_locks.sh >> log/clean_up_worker_locks.log 2>&1'"


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

add_job "$cron_nlims_worker"
add_job "$cron_master_nlims_sync"
add_job "$cron_emr"
add_job "$cron_rm_stale_locks"

echo
echo "Note: UpdateOrderSourceCouchIdJob is scheduled via Sidekiq Cron (config/schedule.yml)"
echo
echo "============================================"
echo "      NLIMS CRON INSTALLATION COMPLETE"
echo "============================================"
