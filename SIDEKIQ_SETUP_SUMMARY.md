# Sidekiq Migration Summary

## What Was Done

### 1. Created Sidekiq Worker Jobs (6 total)

- **LogTrackingNumbersJob** - Logs tracking numbers every 5 minutes
- **SyncToNlimsJob** - Syncs orders, tests, results every 5 minutes
- **PullFromMasterNlimsJob** - Pulls from master NLIMS every 3 hours
- **AcknowledgeResultsJob** - Acknowledges results every 30 minutes
- **UpdateOrderSourceCouchIdJob** - Updates couch IDs every 5 hours
- **CleanupStaleLockJob** - Cleans lock files weekly (Saturday 3am)

All jobs located in: `app/jobs/`

### 2. Configured Scheduling

- Updated: `config/schedule.yml` with all job schedules
- Updated: `config/initializers/sidekiq.rb` to load schedules
- Jobs use `sidekiq-unique-jobs` to prevent duplicates

### 3. Created Deployment Files

- **config/nlims-sidekiq.service** - Systemd service file
- **bin/setup_sidekiq.sh** - Automated setup script
- **config/crontab.example** - Example simplified crontab
- **SIDEKIQ_MIGRATION_GUIDE.md** - Complete migration documentation

## How It Works

### Duplicate Prevention

Each job uses `sidekiq-unique-jobs` with:

```ruby
sidekiq_options lock: :until_executed,
                on_conflict: :log
```

**What this means:**

- ✅ If LogTrackingNumbersJob is running, another LogTrackingNumbersJob **cannot start**
- ✅ Once the job completes, the next scheduled run **can proceed**
- ✅ No need for flock or lock files
- ✅ Duplicate attempts are **logged** for monitoring

### Job Queue Priority

```
critical (highest) → high_priority → default → low_priority (lowest)
```

- **SyncToNlimsJob** runs in `critical` queue (processed first)
- **Pull/Acknowledge jobs** run in `high_priority` queue
- **Cleanup/Update jobs** run in `low_priority` queue

### Concurrency Control

Set in `config/sidekiq.yml`:

```yaml
:concurrency: 5 # Maximum 5 jobs run simultaneously
```

Sidekiq will:

- Process critical jobs first
- Never run duplicate jobs simultaneously
- Queue jobs if concurrency limit reached
- Retry failed jobs automatically

## Quick Start

### Option 1: Automated Setup (Recommended)

```bash
sudo ./bin/setup_sidekiq.sh
```

### Option 2: Manual Setup

```bash
# 1. Start Redis
sudo systemctl start redis

# 2. Install systemd service
sudo cp config/nlims-sidekiq.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable nlims-sidekiq
sudo systemctl start nlims-sidekiq

# 3. Verify
sudo systemctl status nlims-sidekiq
```

### Option 3: Development/Testing

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

## Verify Setup

```bash
# Check Sidekiq is running
sudo systemctl status nlims-sidekiq

# Check scheduled jobs
bundle exec rails console
> Sidekiq::Cron::Job.all.each { |j| puts "#{j.name}: #{j.status}" }

# Monitor logs
tail -f log/sidekiq.log
```

## Migration Checklist

- [ ] Redis is installed and running
- [ ] Run setup script: `sudo ./bin/setup_sidekiq.sh`
- [ ] Verify Sidekiq service is running
- [ ] Verify jobs are scheduled (6+ jobs)
- [ ] Monitor first execution cycle (wait 5 minutes)
- [ ] Check logs for errors: `tail -f log/sidekiq.log`
- [ ] Remove old cronjobs: `crontab -e`
- [ ] Monitor for 24 hours to ensure stability

## Monitoring

### Command Line

```bash
# Service status
sudo systemctl status nlims-sidekiq

# Live logs
tail -f log/sidekiq.log

# System logs
sudo journalctl -u nlims-sidekiq -f

# Check scheduled jobs
bundle exec rails runner "Sidekiq::Cron::Job.all.each { |j| puts j.name }"
```

### Web UI (if mounted)

Access: `http://your-server/sidekiq`

- View queues
- See running jobs
- Monitor dead jobs
- Check scheduled jobs

## Troubleshooting

### Jobs not running?

```bash
# Check Redis
redis-cli ping  # Should return PONG

# Check Sidekiq process
ps aux | grep sidekiq

# Restart service
sudo systemctl restart nlims-sidekiq
```

### Stuck jobs?

```bash
bundle exec rails console
> Sidekiq::Queue.new('critical').clear
> Sidekiq::RetrySet.new.clear
```

### Reload schedule?

```bash
bundle exec rails console
> Sidekiq::Cron::Job.load_from_hash(YAML.load_file('config/schedule.yml'))
```

## Comparison: Before vs After

### Before (Cronjobs + flock)

```bash
# 6 separate cronjob entries
# Each with flock lock file
# Scattered logs
# No retry on failure
# Hard to monitor
# Manual lock cleanup needed
```

### After (Sidekiq)

```bash
# 1 systemd service
# Automatic locking via sidekiq-unique-jobs
# Centralized logging
# Automatic retries
# Web UI monitoring
# No lock file management
```

## Benefits Achieved

✅ **No Duplicate Execution** - `sidekiq-unique-jobs` ensures only one instance runs
✅ **Optimal Performance** - Queue priority ensures critical jobs run first
✅ **Better Monitoring** - Web UI + structured logs
✅ **Automatic Retries** - Failed jobs retry automatically
✅ **Graceful Shutdown** - Jobs complete before restart
✅ **Resource Control** - Configurable concurrency
✅ **Centralized Management** - All jobs in one place
✅ **No Lock Files** - No `/tmp` lock file management

## Files Modified/Created

### Created:

- `app/jobs/log_tracking_numbers_job.rb`
- `app/jobs/sync_to_nlims_job.rb`
- `app/jobs/pull_from_master_nlims_job.rb`
- `app/jobs/acknowledge_results_job.rb`
- `app/jobs/update_order_source_couch_id_job.rb`
- `app/jobs/cleanup_stale_lock_job.rb`
- `config/nlims-sidekiq.service`
- `bin/setup_sidekiq.sh`
- `config/crontab.example`
- `SIDEKIQ_MIGRATION_GUIDE.md`
- `SIDEKIQ_SETUP_SUMMARY.md` (this file)

### Modified:

- `config/schedule.yml` - Added 6 new job schedules
- `config/initializers/sidekiq.rb` - Added schedule loading

### Unchanged (used by jobs):

- `app/services/sync_to_nlims_service.rb`
- All rake tasks in `lib/tasks/`
- All supporting services

## Support

See `SIDEKIQ_MIGRATION_GUIDE.md` for detailed documentation.

For immediate help:

- Check logs: `tail -f log/sidekiq.log`
- Check service: `sudo systemctl status nlims-sidekiq`
- Check Redis: `redis-cli ping`
