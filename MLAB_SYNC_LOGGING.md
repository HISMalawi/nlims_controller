# MLAB Sync Logging & Progress Tracking

## Log Files

The sync script creates two types of log files in the `log/` directory:

### 1. Sync Log (`log/mlab_sync.log`)
- **Format**: Daily rotating log
- **Contains**: 
  - Sync start/end timestamps
  - Batch processing progress
  - Error messages
  - Summary statistics
  - Last processed test ID

**Example log entries:**
```
[2026-03-18 10:30:00] INFO: ================================================================================
[2026-03-18 10:30:00] INFO: SYNC STARTED: 2026-03-18 10:30:00 +0200
[2026-03-18 10:30:00] INFO: Facility: Queen Elizabeth Central Hospital Laboratory, District: Blantyre
[2026-03-18 10:30:00] INFO: Starting from Test ID: 0, Limit: None
[2026-03-18 10:30:05] INFO: Total tests to sync: 1600000
[2026-03-18 10:30:10] INFO: Batch #1: Processing 100 tests (offset 0)
[2026-03-18 10:31:45] INFO: Progress: Last Test ID 98, Total: 25, Created: 20, Updated: 3, Skipped: 1, Failed: 1
[2026-03-18 10:33:20] INFO: Batch #1: Completed in 190.5s
```

### 2. Checkpoint File (`log/mlab_sync_checkpoint.txt`)
- **Format**: JSON
- **Updated**: Every 25 records and at end of each batch
- **Contains**: Current sync state for resuming

**Example checkpoint:**
```json
{
  "last_test_id": 98,
  "total_processed": 100,
  "total_created": 85,
  "total_updated": 10,
  "total_skipped": 3,
  "total_failed": 2,
  "timestamp": "2026-03-18 10:33:20 +0200"
}
```

## Resuming a Failed Sync

If the sync crashes or is interrupted:

1. **Check the last processed test ID:**
   ```bash
   cat log/mlab_sync_checkpoint.txt
   ```

2. **Resume from that ID:**
   ```bash
   bundle exec ruby bin/mlab_to_nlims_sync.rb
   # When prompted for starting test ID, enter the last_test_id from checkpoint
   ```

3. **Or view the log directly:**
   ```bash
   tail -n 50 log/mlab_sync.log
   # Look for "Last Test ID Processed" in the final summary
   ```

## Monitoring Progress

### Real-time monitoring:
```bash
tail -f log/mlab_sync.log
```

### Check current checkpoint:
```bash
watch -n 5 'cat log/mlab_sync_checkpoint.txt | jq .'
```

### View sync statistics:
```bash
grep "Progress:" log/mlab_sync.log | tail -20
```

## Log Rotation

The sync log rotates daily automatically. Old logs are kept with date suffix:
- `mlab_sync.log` (current)
- `mlab_sync.log.20260317` (previous day)
- etc.

## Troubleshooting

### Find errors in log:
```bash
grep "ERROR:" log/mlab_sync.log
```

### Find warnings:
```bash
grep "WARNING:" log/mlab_sync.log
```

### Check sync duration:
```bash
grep -E "(SYNC STARTED|SYNC COMPLETED)" log/mlab_sync.log
```

### View last sync summary:
```bash
grep -A 10 "SYNC COMPLETED" log/mlab_sync.log | tail -15
```

## Best Practices

1. **Monitor checkpoint regularly** during large syncs
2. **Keep checkpoint file** until sync completes successfully
3. **Review log for errors** before resuming a failed sync
4. **Use checkpoint to estimate completion time** based on current rate
5. **Archive logs** after successful completion for audit trail
