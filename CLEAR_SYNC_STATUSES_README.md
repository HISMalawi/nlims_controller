# Process Sync Statuses & Clear Sidekiq Queues Script

## Overview

This script efficiently processes sync status records up to a specified date and clears Sidekiq job queues. It performs three main operations:

**1. Mark as Synced (For sync trackers)** - Sets sync flags to true, preserving all data for auditing while preventing re-processing by sync jobs.

**2. Delete (For error logs)** - Permanently removes old error logs that don't need long-term storage.

**3. Clear Sidekiq Queues** - Clears all Sidekiq job queues including scheduled, retries, dead, enqueued, and resets processed/failed stats.

### Benefits of This Approach

For sync trackers:

- ✅ Data is preserved for auditing and troubleshooting
- ✅ Recoverable if something goes wrong
- ✅ No data loss risk
- ✅ Maintains complete historical records
- ✅ Can still be deleted later if needed

For error logs:

- ✅ Reduces database bloat from temporary error records
- ✅ Improves query performance
- ✅ Error logs typically have limited long-term value

For Sidekiq queues:

- ✅ Removes stale/stuck jobs from all queues
- ✅ Clears scheduled, retry, and dead job sets
- ✅ Resets processed and failed statistics
- ✅ Prevents re-execution of old sync jobs
- ⚠️ **Note**: Active (busy) jobs cannot be cleared while processing

## How It Works

The script performs two types of operations:

### Marking as Synced (Preserves Data)

Updates the following fields to mark records as processed:

1. **status_sync_trackers** → Sets `sync_status = true`
2. **order_sync_trackers** → Sets `synced = true`
3. **order_status_sync_trackers** → Sets `sync_status = true`
4. **results_sync_trackers** → Sets `sync_status = true`
5. **added_test_sync_trackers** → Sets `sync_status = true`

### Deleting Records (Removes Data)

6. **sync_error_logs** → Deleted permanently (error logs don't need preservation)

### Clearing Sidekiq Queues (After Processing)

After processing sync records, the script automatically clears all Sidekiq queues:

1. **Scheduled jobs** → All scheduled jobs cleared
2. **Retry set** → Failed jobs pending retry cleared
3. **Dead set** → Dead jobs that exceeded retry limit cleared
4. **All queues** → All enqueued jobs in every queue cleared
5. **Statistics** → Processed and failed counters reset to 0
6. **Busy jobs** → Cannot be cleared (currently being processed by workers)

## Affected Tables

The script processes the following sync tracker tables:

### Marked as Synced (Data Preserved)

1. **status_sync_trackers** - Status sync tracking → `sync_status = true`
2. **order_sync_trackers** - Order sync tracking → `synced = true`
3. **order_status_sync_trackers** - Order status sync tracking → `sync_status = true`
4. **results_sync_trackers** - Results sync tracking → `sync_status = true`
5. **added_test_sync_trackers** - Added test sync tracking → `sync_status = true`

### Deleted (Data Removed)

6. **sync_error_logs** - Sync error logs → **Deleted** (error logs don't need long-term storage)

### Not Processed

7. **mlab_sync_failures** - Not included (handle separately if needed)

## Usage

### Shell Script (Recommended)

```bash
# Mark records up to a specific date as synced
./bin/clear_sync_statuses.sh "2024-12-31" 10000

# Mark records older than 3 months as synced (default batch size)
./bin/clear_sync_statuses.sh "3 months ago"

# Mark records older than 6 months with custom batch size
./bin/clear_sync_statuses.sh "6 months ago" 5000

# Mark records older than 1 year as synced
./bin/clear_sync_statuses.sh "1 year ago"
```

### Ruby Script (Direct)

```bash
# Using bundle exec
bundle exec ruby bin/clear_sync_statuses.rb "2024-12-31" 10000

# With different environments
RAILS_ENV=development bundle exec ruby bin/clear_sync_statuses.rb "3 months ago"
```

## Parameters

1. **end_date** (required, default: "3 months ago")
   - Date string in format: `YYYY-MM-DD` (e.g., "2024-12-31")
   - Relative time string (e.g., "3 months ago", "1 year ago", "6 months ago")
   - All unsynced records with `created_at <= end_date` will be marked as synced

2. **batch_size** (optional, default: 10000)
   - Number of records to update per batch
   - Larger batches = faster updates but more database load
   - Smaller batches = slower but safer for production
   - Recommended range: 5000-20000

## Optimization Features

### 1. Batch Processing

- Deletes records in configurable batches to avoid long-running transactions
- Prevents table locks that could impact production operations
- Default batch size: 10,000 records

### 2. Progress Tracking

- Real-time progress updates showing records updated and percentage complete
- Helps monitor long-running operations

### 3. Error Handling

- Graceful handling of missing models or tables
- Detailed error messages with backtrace for debugging
- Continues processing other tables if one fails

### 4. Database-Level Optimization

- Uses direct `UPDATE` SQL with `WHERE` clause for efficiency
- Avoids loading records into memory (no ActiveRecord object instantiation)
- Only updates unsynced records, skipping already synced ones
- Minimizes database overhead

### 5. Safety Features

- Production environment confirmation prompt (in shell script)
- Counts unsynced records before updating
- Summary report after completion
- **Data preservation** - records are marked, not deleted

## Performance Considerations

### Estimated Update Speed

- ~10,000-50,000 records per second (depending on database performance)
- For 1 million records: approximately 20-100 seconds
- Updates are faster than deletes (no index reorganization needed)

### Database Load

- Small sleep (0.1s) between batches to avoid overwhelming the database
- Adjust batch size based on your database capacity

### Recommended Batch Sizes

- **Low traffic periods**: 20,000 records
- **Normal operations**: 10,000 records (default)
- **High traffic periods**: 5,000 records
- **Very sensitive systems**: 1,000 records

## Post-Processing

### Optional: Delete Old Synced Records

If you want to actually delete records after marking them as synced (for space reclamation):

```sql
-- Delete synced records older than a specific date (if you want to reclaim more space)
DELETE FROM status_sync_trackers
WHERE sync_status = true AND created_at <= '2024-12-31';

DELETE FROM order_sync_trackers
WHERE synced = true AND created_at <= '2024-12-31';

DELETE FROM order_status_sync_trackers
WHERE sync_status = true AND created_at <= '2024-12-31';

DELETE FROM results_sync_trackers
WHERE sync_status = true AND created_at <= '2024-12-31';

DELETE FROM added_test_sync_trackers
WHERE sync_status = true AND created_at <= '2024-12-31';

-- Note: sync_error_logs are already deleted by the script
```

### Optimize Database (MySQL)

After updates (or deletions), reclaim disk space and update statistics:

```sql
-- Run in MySQL to update statistics (lightweight, safe during production)
ANALYZE TABLE status_sync_trackers;
ANALYZE TABLE order_sync_trackers;
ANALYZE TABLE order_status_sync_trackers;
ANALYZE TABLE results_sync_trackers;
ANALYZE TABLE added_test_sync_trackers;
ANALYZE TABLE sync_error_logs;

-- Or if you deleted records, optimize to reclaim space (heavier operation)
OPTIMIZE TABLE
  status_sync_trackers,
  order_sync_trackers,
  order_status_sync_trackers,
  results_sync_trackers,
  added_test_sync_trackers,
  sync_error_logs;
```

### Check Table Sizes

```sql
-- Check table sizes and counts
SELECT
  TABLE_NAME,
  ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) AS 'Size (MB)',
  TABLE_ROWS AS 'Row Count'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE '%sync%'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;

-- Check synced vs unsynced counts
SELECT
  'status_sync_trackers' as table_name,
  COUNT(*) as total,
  SUM(CASE WHEN sync_status = true THEN 1 ELSE 0 END) as synced,
  SUM(CASE WHEN sync_status = false THEN 1 ELSE 0 END) as unsynced
FROM status_sync_trackers
UNION ALL
SELECT
  'order_sync_trackers',
  COUNT(*),
  SUM(CASE WHEN synced = true THEN 1 ELSE 0 END),
  SUM(CASE WHEN synced = false THEN 1 ELSE 0 END)
FROM order_sync_trackers;
```

### Check Disk Space Reclaimed

```bash
# Check MySQL data directory size
du -sh /var/lib/mysql

# Or check specific database
du -sh /var/lib/mysql/your_database_name
```

## Examples

### Mark old test data as synced (development)

```bash
RAILS_ENV=development ./bin/clear_sync_statuses.sh "1 month ago"
```

### Mark 6-month-old production data as synced

```bash
RAILS_ENV=production ./bin/clear_sync_statuses.sh "6 months ago" 10000
```

### Mark data before specific date as synced

```bash
./bin/clear_sync_statuses.sh "2024-06-30" 15000
```

### Mark 1 year of data in smaller batches (safer)

```bash
./bin/clear_sync_statuses.sh "1 year ago" 5000
```

## Monitoring

The script outputs:

- Total unsynced records found per table (for marking)
- Total records found for deletion (sync_error_logs)
- Progress updates during marking/deletion
- Total records marked as synced per table
- Total records deleted
- Sidekiq queues cleared (with counts)
- Overall summary with timing
- Reminder about data preservation vs deletion

Example output:

```
================================================================================
SYNC STATUS PROCESSING SCRIPT
================================================================================
End Date: 2024-12-31 23:59:59 +0000
Batch Size: 10000
Actions:
  - Sync trackers: Marked as synced (data preserved)
  - Error logs: Deleted (data removed)
================================================================================

Starting sync status marking process...

Processing: Status Sync Tracker (status_sync_trackers)
  Found 45000 unsynced records to mark as synced
  Progress: 10000/45000 (22.22%)
  Progress: 20000/45000 (44.44%)
  Progress: 30000/45000 (66.67%)
  Progress: 40000/45000 (88.89%)
  Progress: 45000/45000 (100.0%)
  ✓ Marked 45000 records as synced

...

Processing: Sync Error Log (sync_error_logs)
  Found 12000 records to delete
  Progress: 10000/12000 (83.33%)
  Progress: 12000/12000 (100.0%)
  ✓ Deleted 12000 records

================================================================================
PROCESSING SUMMARY
================================================================================
Total records marked as synced: 233000
Total records deleted: 12000
Duration: 42.18 seconds
Completed at: 2025-01-15 14:30:00 +0000
================================================================================

ℹ️  Sync tracker records are marked as synced (preserved for auditing)
ℹ️  Sync error logs are deleted (older than 2024-12-31)

================================================================================
CLEARING SIDEKIQ QUEUES
================================================================================

  ✓ Cleared scheduled queue: 1523 jobs
  ✓ Cleared retry queue: 342 jobs
  ✓ Cleared dead queue: 89 jobs
  ✓ Cleared 'default' queue: 456 jobs
  ✓ Cleared 'sync' queue: 2341 jobs
  ✓ Cleared 'mailers' queue: 12 jobs
  ✓ Reset processed count: 1234567
  ✓ Reset failed count: 8901
  ℹ️  Currently busy jobs (cannot be cleared): 3

Sidekiq queues cleared successfully!

================================================================================
FINAL SUMMARY
================================================================================
Sync Processing:
  - Records marked as synced: 233000
  - Records deleted: 12000
  - Duration: 42.18 seconds

Sidekiq Queues Cleared:
  - scheduled: 1523 jobs
  - retries: 342 jobs
  - dead: 89 jobs
  - default: 456 jobs
  - sync: 2341 jobs
  - mailers: 12 jobs
  - processed_stats: 1234567
  - failed_stats: 8901
  - busy_active: 3
================================================================================

✅ All operations completed successfully!
```

## Scheduling with Cron

To run automatically:

```bash
# Edit crontab
crontab -e

# Mark old records as synced monthly (runs on 1st of each month at 2 AM)
0 2 1 * * cd /path/to/nlims_controller && RAILS_ENV=production ./bin/clear_sync_statuses.sh "6 months ago" 10000 >> /var/log/nlims/sync_marking.log 2>&1

# Mark old records weekly (runs every Sunday at 3 AM)
0 3 * * 0 cd /path/to/nlims_controller && RAILS_ENV=production ./bin/clear_sync_statuses.sh "3 months ago" 10000 >> /var/log/nlims/sync_marking.log 2>&1
```

## Troubleshooting

### Script fails with "Model not found"

- Ensure all model files exist in `app/models/`
- Check that models are properly loaded in your Rails environment

### Database connection timeout

- Reduce batch size
- Run during off-peak hours
- Check database connection pool settings

### Already synced records

- The script only updates records where sync_status/synced = false
- Already synced records are automatically skipped
- No performance impact from running multiple times

### Out of memory errors

- The script uses direct SQL updates (not loading into memory)
- If still occurring, reduce batch size significantly
- Check available database server memory

### Records still being processed by sync jobs

- This is safe! The script marks records as completed
- Sync jobs check the sync status flag and skip processed records
- No duplicate processing will occur

### Lock timeout

- Reduce batch size to shorten transaction duration
- Run during low-traffic periods
- Check MySQL `innodb_lock_wait_timeout` setting
- Consider temporarily increasing timeout for this operation

## Safety Notes

✅ **Sync Trackers: SAFE and REVERSIBLE!** Records are marked, not deleted.
⚠️ **Error Logs: PERMANENT DELETION!** Cannot be recovered unless you have backups.
❌ **Sidekiq Queues: PERMANENT DELETION!** All queued jobs will be lost and cannot be recovered.

### Key Benefits:

1. **Data preservation** - Sync trackers maintain complete audit trail
2. **Reversible** - Can unmark sync trackers if needed: `UPDATE table SET sync_status = false WHERE ...`
3. **Space optimization** - Error logs are deleted to reduce bloat
4. **Performance** - Sync jobs skip already processed records
5. **Flexibility** - Can delete marked sync records later if space is needed
6. **Clean slate** - Sidekiq queues are cleared to prevent old jobs from running

### Critical Warnings:

⚠️ **Sidekiq Queue Clearing**:

- **ALL queued jobs will be permanently lost** (scheduled, retry, dead, enqueued)
- Jobs cannot be recovered after clearing
- Only run during maintenance windows when job loss is acceptable
- Active/busy jobs cannot be cleared but will complete
- Consider the impact on system operations before running

### Recommendations:

1. **Backup before running in production** (especially for error log deletion)
2. **Test in development/staging first** to verify behavior
3. **Run during low-traffic/maintenance periods** for optimal performance
4. **Stop Sidekiq workers** before running if you want to avoid busy jobs
5. **Monitor sync job behavior** after marking to ensure correct operation
6. **Keep marked records** for at least 30-90 days before deletion
7. **Retain recent error logs** - only delete logs older than necessary (e.g., 3-6 months)
8. **Verify no critical jobs are queued** before clearing Sidekiq

## Support

For issues or questions, contact the development team or check the NLIMS documentation.
