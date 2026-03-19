#!/bin/bash
# Shell wrapper for marking sync statuses as synced
# Usage: ./bin/clear_sync_statuses.sh [end_date] [batch_size]
# Example: ./bin/clear_sync_statuses.sh "2024-12-31" 10000
# Example: ./bin/clear_sync_statuses.sh "3 months ago" 5000

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR" || exit 1

# Get the current environment (default to production)
RAILS_ENV="${RAILS_ENV:-production}"

echo "==================================================================="
echo "Mark Sync Statuses as Synced Script"
echo "==================================================================="
echo "Environment: $RAILS_ENV"
echo "Project Directory: $PROJECT_DIR"
echo "Arguments: $*"
echo "Action: Marking sync trackers as synced, deleting error logs"
echo "==================================================================="
echo

# Confirmation prompt for production
if [ "$RAILS_ENV" = "production" ]; then
  echo "INFO: This script will process sync records in PRODUCTION:"
  echo "      - Sync trackers: marked as synced (preserved for auditing)"
  echo "      - Error logs: deleted permanently"
  echo
  read -p "Are you sure you want to continue? (yes/no): " -r
  echo
  if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Operation cancelled."
    exit 0
  fi
fi

# Run the Ruby script
bundle exec ruby "$SCRIPT_DIR/clear_sync_statuses.rb" "$@"

exit_code=$?

if [ $exit_code -eq 0 ]; then
  echo
  echo "✓ Processing completed successfully"
  echo
  echo "INFO: Sync trackers are marked as synced (preserved for auditing)"
  echo "      Error logs are deleted permanently"
  echo
else
  echo
  echo "✗ Processing failed with exit code: $exit_code"
  echo
fi

exit $exit_code
