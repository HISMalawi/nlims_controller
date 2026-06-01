#!/bin/bash

# Clean up stale worker locks
# This script removes lock files for workers that are no longer running

LOCK_DIR="/home/hopgausi/HisMalawi/nlims_controller/log/workers"

if [ ! -d "$LOCK_DIR" ]; then
  echo "Lock directory does not exist: $LOCK_DIR"
  exit 0
fi

echo "Cleaning up stale worker locks in $LOCK_DIR"

for lock_file in "$LOCK_DIR"/*.lock; do
  if [ -f "$lock_file" ]; then
    # Extract PID from lock file
    pid=$(grep -oP 'process #\K[0-9]+' "$lock_file" 2>/dev/null)
    
    if [ -n "$pid" ]; then
      # Check if process is still running
      if ! ps -p "$pid" > /dev/null 2>&1; then
        echo "Removing stale lock: $lock_file (PID $pid no longer running)"
        rm -f "$lock_file"
      else
        echo "Lock file $lock_file is still valid (PID $pid is running)"
      fi
    else
      echo "Removing invalid lock file: $lock_file (no PID found)"
      rm -f "$lock_file"
    fi
  fi
done

echo "Stale lock cleanup completed"
