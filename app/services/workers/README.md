# NLIMS Background Workers

This directory contains all background worker classes for the NLIMS Controller application.

## Worker Organization

All worker files are organized in this `app/services/workers/` directory for better code organization and maintainability.

### Main Coordinator

- **nlims_worker.rb** - Main worker coordinator module that manages and forks all workers

### Shared Components

- **nlims_data_processor.rb** - Shared module with common NLIMS data processing logic used by multiple workers

### Worker Classes

#### Synchronization Workers (Run every 5 minutes via cron)

1. **log_tracking_numbers_worker.rb**
   - Logs tracking numbers from master NLIMS
   - Batch size: 50,000 records

2. **test_catalog_sync_worker.rb**
   - Synchronizes test catalog from NLIMS
   - Local NLIMS only

3. **push_orders_worker.rb**
   - Pushes orders to NLIMS
   - Handles: regular push, force sync, updates, added tests

4. **push_results_worker.rb**
   - Pushes status updates and test results to NLIMS

5. **push_acknowledgements_worker.rb**
   - Pushes acknowledgements to master NLIMS

6. **master_nlims_sync_data_worker.rb**
   - Syncs data from master NLIMS
   - Pushes updates to EMR
   - Uses shared NlimsDataProcessor

#### Scheduled Workers (Sidekiq Cron)

7. **update_order_source_couch_id_worker.rb**
   - Updates order source CouchDB document IDs
   - Scheduled: Weekly Friday at 3pm via UpdateOrderSourceCouchIdJob

## Worker Execution Flow

### Cron-Based Workers (Every 5 minutes)
```
bin/worker.rb (cron trigger)
    ↓
NlimsWorker.start
    ↓
Forks 7 parallel workers:
├─ LogTrackingNumbersWorker
├─ TestCatalogSyncWorker
├─ PushOrdersWorker
├─ PushResultsWorker
├─ PushAcknowledgementsWorker
├─ MasterNlimsSyncDataWorker
└─ MasterNlimsSyncAckWorker (if exists)
    ↓
Each worker runs independently with file-based locking
```

### Sidekiq Job Wrapper
```
UpdateOrderSourceCouchIdJob (Sidekiq)
    ↓
UpdateOrderSourceCouchIdWorker.run
```

## Autoloading

Workers are automatically loaded by Rails from this directory via:

```ruby
# config/application.rb
config.autoload_paths += %W[#{config.root}/app/services/workers]
```

No explicit `require` statements needed - Rails handles autoloading automatically.

## Logging

Each worker logs to its own file in `log/workers/`:
- `log_tracking_numbers_worker.log`
- `test_catalog_sync_worker.log`
- `push_orders_worker.log`
- `push_results_worker.log`
- `push_acknowledgements_worker.log`
- `master_nlims_sync_data_worker.log`
- `nlims_worker.log` (main coordinator)

## Locking

Workers use file-based locking in `log/workers/`:
- Each worker creates a `.lock` file with its PID
- Prevents duplicate worker execution
- Lock files automatically cleaned weekly via `clean_up_worker_locks.sh`

## Adding a New Worker

1. Create worker file in this directory:
```ruby
# app/services/workers/my_new_worker.rb
class MyNewWorker
  def run
    Rails.logger.info('Starting my new worker')
    # Your logic here
    Rails.logger.info('My new worker completed')
  rescue StandardError => e
    Rails.logger.error("Error: #{e.class} - #{e.message}")
    raise
  end
end
```

2. Add to NlimsWorker coordinator (if needed for cron execution):
```ruby
# In nlims_worker.rb
def self.start
  # ...
  fork { start_my_new_worker }
  # ...
end

def self.start_my_new_worker
  start_worker('my_new_worker') do
    worker = MyNewWorker.new
    worker.run
  end
end
```

3. For scheduled execution, create a Sidekiq job wrapper in `app/jobs/` and add to `config/schedule.yml`

## Documentation

See main documentation files:
- [WORKERS.md](../../WORKERS.md) - Complete worker system documentation
- [PARALLELIZATION.md](../../PARALLELIZATION.md) - Worker parallelization explanation
- [REFACTORING.md](../../REFACTORING.md) - Code refactoring notes
