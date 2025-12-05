#!/bin/bash

#############################################
#  CLEAN UP STALE LOCKS
#############################################

echo "Cleaning up stale NLIMS cron job locks in /tmp..."
LOCK_DIR="/tmp"

rm -f "$LOCK_DIR/log_tracking_numbers.lock" \
      "$LOCK_DIR/sync_sh.lock" \
      "$LOCK_DIR/nlims_sync_data.lock" \
      "$LOCK_DIR/nlims_ack.lock" \
      "$LOCK_DIR/nlims_update_couch_id.lock" \
      "$LOCK_DIR/nlims_sync.lock" \
      "$LOCK_DIR/nlims_sync_migrate.lock" \
      "$LOCK_DIR/update_elasticsearch_index.lock"

echo "Stale locks removed (if they existed)."
echo