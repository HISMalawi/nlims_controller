#!/bin/bash

# Parallel Migration Script
# This script helps you run multiple migration instances in parallel
# Each instance processes a different datetime range

# INSTRUCTIONS:
# 1. Adjust the datetime ranges below to match your data
# 2. Make the script executable: chmod +x bin/mlab/parallel_migrate.sh
# 3. Run in background: ./bin/mlab/parallel_migrate.sh
#
# MONITORING:
# - Each instance logs to a separate file: logs/migrate_START_to_END.log
# - Check progress: tail -f logs/migrate_*.log
# - Monitor all: watch 'tail -n 5 logs/migrate_*.log'

# Create logs directory if it doesn't exist
mkdir -p logs

# Function to run migration for a datetime range
run_migration() {
  local start_datetime=$1
  local end_datetime=$2
  local log_name=$(echo "${start_datetime}_to_${end_datetime}" | tr ' :' '__')
  local log_file="logs/migrate_${log_name}.log"
  
  echo "Starting migration for ${start_datetime} to ${end_datetime}..."
  echo "Logging to: ${log_file}"
  
  # Run migration with input provided via heredoc
  bundle exec rails runner bin/mlab/migrate_data.rb > "$log_file" 2>&1 <<EOF
n
${start_datetime}
${end_datetime}
EOF
  
  echo "Completed migration for ${start_datetime} to ${end_datetime}"
}

# Example datetime ranges - CUSTOMIZE THESE FOR YOUR DATA
# Format: YYYY-MM-DD HH:MM:SS or YYYY-MM-DD (date defaults to 00:00:00 start, 23:59:59 end)

echo "=================================="
echo "PARALLEL MIGRATION LAUNCHER"
echo "=================================="
echo ""
echo "This will start 4 parallel migration processes."
echo "Each process will handle a different datetime range."
echo ""
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

# OPTION 1: Split by quarters (recommended for large yearly datasets)
run_migration "2024-01-01 00:00:00" "2024-03-31 23:59:59" &
sleep 2  # Small delay to avoid startup conflicts

run_migration "2024-04-01 00:00:00" "2024-06-30 23:59:59" &
sleep 2

run_migration "2024-07-01 00:00:00" "2024-09-30 23:59:59" &
sleep 2

run_migration "2024-10-01 00:00:00" "2024-12-31 23:59:59" &
sleep 2

# OPTION 2: Split by hours within a busy day (uncomment to use)
# run_migration "2024-06-15 00:00:00" "2024-06-15 05:59:59" &
# sleep 2
# run_migration "2024-06-15 06:00:00" "2024-06-15 11:59:59" &
# sleep 2
# run_migration "2024-06-15 12:00:00" "2024-06-15 17:59:59" &
# sleep 2
# run_migration "2024-06-15 18:00:00" "2024-06-15 23:59:59" &
# sleep 2

echo ""
echo "=================================="
echo "All migration processes launched!"
echo "=================================="
echo ""
echo "Monitor progress with:"
echo "  tail -f logs/migrate_*.log"
echo ""
echo "Check running processes:"
echo "  ps aux | grep migrate_data"
echo ""
echo "Wait for all to complete with:"
echo "  wait"
echo ""

# Wait for all background jobs to complete
wait

echo ""
echo "=================================="
echo "ALL MIGRATIONS COMPLETED"
echo "=================================="
echo ""
echo "Check results in:"
echo "  ls -lh logs/migrate_*.log"
