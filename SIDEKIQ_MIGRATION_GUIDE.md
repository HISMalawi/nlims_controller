# Sidekiq Job Scheduling Migration Guide

## Overview

This guide explains the migration from traditional cron-based job scheduling with flock to a Sidekiq-managed approach using `sidekiq-cron` and `sidekiq-unique-jobs`.

## Why Migrate to Sidekiq?

### Problems with the Old Approach:

1. **Multiple cron entries** - Hard to manage and monitor
2. **flock complexity** - Required external lock files in `/tmp`
3. **No retry mechanism** - Failed jobs lost forever
4. **Poor monitoring** - Difficult to track job execution
5. **No job queue** - Jobs run regardless of system load
6. **Limited logging** - Scattered logs across multiple files

### Benefits of Sidekiq Approach:

1. **Centralized scheduling** - All jobs defined in `config/schedule.yml`
2. **Automatic locking** - `sidekiq-unique-jobs` prevents duplicate execution
3. **Built-in retries** - Failed jobs automatically retry
4. **Web UI monitoring** - Real-time job status via Sidekiq Web UI
5. **Priority queues** - Critical jobs run first
6. **Better logging** - All jobs log to Rails logger
7. **Resource management** - Configurable concurrency
8. **Graceful shutdown** - Jobs complete before restart

## New Job Structure

### Created Jobs:

1. **LogTrackingNumbersJob** (Every 5 minutes)
   - Logs tracking numbers from central NLIMS
   - Queue: `default`
   - Replaces: `bin/log_tracking_numbers.sh`

2. **SyncToNlimsJob** (Every 5 minutes)
   - Syncs orders, tests, results, and status to NLIMS
   - Queue: `critical` (highest priority)
   - Replaces: `bin/sync.sh`

3. **PullFromMasterNlimsJob** (Every 3 hours)
   - Pulls test results from master NLIMS
   - Queue: `high_priority`
   - Replaces: `rake master_nlims:sync_data`

4. **AcknowledgeResultsJob** (Every 30 minutes)
   - Syncs acknowledgements for delivered results
   - Queue: `high_priority`
   - Replaces: `rake master_nlims:sync_local_nlims_acknowledge_results`

5. **UpdateOrderSourceCouchIdJob** (Every 5 hours)
   - Updates order source couch IDs
   - Queue: `low_priority`
   - Replaces: `rake master_nlims:update_order_source_couch_id`

6. **CleanupStaleLockJob** (Weekly: Saturday 3am)
   - Cleans up legacy lock files
   - Queue: `low_priority`
   - Replaces: `bin/clean_up_stale_lock.sh`

## Installation & Setup

### Prerequisites:

```bash
# Ensure Redis is installed and running
sudo systemctl status redis
# or
redis-cli ping  # Should return PONG
```

### Start Sidekiq:

#### Development:

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

#### Production (daemon mode):

```bash
RAILS_ENV=production bundle exec sidekiq -C config/sidekiq.yml -d -L log/sidekiq.log
```

### Using systemd (Recommended for Production):

Create `/etc/systemd/system/nlims-sidekiq.service`:

```ini
[Unit]
Description=Sidekiq for NLIMS Controller
After=network.target redis.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/nlims_controller
Environment=RAILS_ENV=production
ExecStart=/bin/bash -lc 'export PATH="$HOME/.rbenv/bin:$PATH" && eval "$(rbenv init -)" && cd /var/www/nlims_controller && rbenv local 3.2.0 && bundle exec sidekiq -C config/sidekiq.yml'
ExecStop=/bin/bash -lc 'export PATH="$HOME/.rbenv/bin:$PATH" && eval "$(rbenv init -)" && cd /var/www/nlims_controller && rbenv local 3.2.0 && bundle exec sidekiqctl stop tmp/pids/sidekiq.pid'

Restart=always
RestartSec=10

StandardOutput=append:/var/www/nlims_controller/log/sidekiq.log
StandardError=append:/var/www/nlims_controller/log/sidekiq.log

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable nlims-sidekiq
sudo systemctl start nlims-sidekiq
sudo systemctl status nlims-sidekiq
```

## Configuration

### Queue Priority Configuration

Edit `config/sidekiq.yml`:

```yaml
:concurrency: 5 # Adjust based on server resources
:queues:
  - critical # Highest priority - SyncToNlimsJob
  - default # Normal priority
  - high_priority # High priority - Pull/Acknowledge jobs
  - low_priority # Low priority - Cleanup/Updates
```

### Job Schedule Configuration

Edit `config/schedule.yml` to modify job schedules:

```yaml
sync_to_nlims_job:
  name: "Sync Orders, Tests, Results and Status to NLIMS"
  cron: "*/5 * * * *" # Every 5 minutes
  class: "SyncToNlimsJob"
  queue: critical
```

Cron format: `minute hour day_of_month month day_of_week`

## Monitoring

### Sidekiq Web UI

Mount in `config/routes.rb` (already done if using Sidekiq):

```ruby
require 'sidekiq/web'
require 'sidekiq/cron/web'

mount Sidekiq::Web => '/sidekiq'
```

Access: `http://your-server/sidekiq`

### Command Line Monitoring

```bash
# Check running jobs
bundle exec sidekiqctl status tmp/pids/sidekiq.pid

# View logs
tail -f log/sidekiq.log

# Check scheduled jobs
bundle exec rails console
> Sidekiq::Cron::Job.all
```

### Job Execution Logs

Each job logs:

- Start: `[JobName] Starting...`
- Progress: `[JobName] Processing item X...`
- End: `[JobName] Completed...`
- Errors: `[JobName] Error: ...`

## How Duplicate Prevention Works

Using `sidekiq-unique-jobs` with `lock: :until_executed`:

```ruby
sidekiq_options lock: :until_executed,
                on_conflict: :log
```

- **lock: :until_executed** - Job locked from queue time until execution completes
- **on_conflict: :log** - Logs when duplicate job is rejected
- No duplicate jobs will execute simultaneously
- If Job A is running, Job A scheduled again will be rejected
- Once Job A completes, next Job A can run

## Migration Steps

### 1. Remove Old Cronjobs:

```bash
crontab -e
# Comment out or remove old NLIMS cronjobs
```

### 2. Copy New Crontab (Optional):

```bash
# Only if not using systemd
crontab config/crontab.example
```

### 3. Start Sidekiq:

```bash
# Using systemd (recommended)
sudo systemctl start nlims-sidekiq

# Or manually
RAILS_ENV=production bundle exec sidekiq -C config/sidekiq.yml -d -L log/sidekiq.log
```

### 4. Verify Jobs Are Scheduled:

```bash
bundle exec rails console
> Sidekiq::Cron::Job.all.each { |j| puts "#{j.name}: #{j.status}" }
```

### 5. Monitor First Execution:

```bash
tail -f log/sidekiq.log
```

## Troubleshooting

### Jobs Not Running?

**Check Sidekiq is running:**

```bash
ps aux | grep sidekiq
# or
sudo systemctl status nlims-sidekiq
```

**Check Redis connection:**

```bash
bundle exec rails console
> Sidekiq.redis { |conn| conn.ping }  # Should return "PONG"
```

**Verify job schedule loaded:**

```bash
bundle exec rails console
> Sidekiq::Cron::Job.count  # Should be > 0
```

### Job Stuck?

**Clear stuck jobs:**

```bash
bundle exec rails console
> Sidekiq::Queue.new('critical').clear
> Sidekiq::RetrySet.new.clear
> Sidekiq::DeadSet.new.clear
```

**Reload schedule:**

```bash
bundle exec rails console
> Sidekiq::Cron::Job.load_from_hash(YAML.load_file('config/schedule.yml'))
```

### High Memory Usage?

**Reduce concurrency in `config/sidekiq.yml`:**

```yaml
:concurrency: 2 # Reduce from 5 to 2
```

**Restart Sidekiq:**

```bash
sudo systemctl restart nlims-sidekiq
```

## Rollback Plan

If issues occur, temporarily restore old cronjobs:

1. Stop Sidekiq:

   ```bash
   sudo systemctl stop nlims-sidekiq
   ```

2. Restore old crontab:

   ```bash
   crontab -e
   # Uncomment old entries
   ```

3. Investigate issue in logs:
   ```bash
   tail -f log/sidekiq.log
   tail -f log/production.log
   ```

## Performance Tuning

### For Heavy Workloads:

```yaml
# config/sidekiq.yml
:concurrency: 10 # Increase workers
:timeout: 60 # Job timeout in seconds
```

### For Limited Resources:

```yaml
# config/sidekiq.yml
:concurrency: 2 # Reduce workers
:timeout: 30
```

## Best Practices

1. **Monitor regularly** - Check Sidekiq Web UI daily
2. **Review logs** - Watch for repeated errors
3. **Test changes** - Use staging/development first
4. **Backup Redis** - Configure Redis persistence
5. **Set alerts** - Monitor Sidekiq process with monitoring tools
6. **Graceful restarts** - Use systemd for proper shutdown
7. **Resource limits** - Set appropriate concurrency

## Additional Resources

- [Sidekiq Documentation](https://github.com/mperham/sidekiq)
- [Sidekiq-Cron](https://github.com/sidekiq-cron/sidekiq-cron)
- [Sidekiq-Unique-Jobs](https://github.com/mhenrixon/sidekiq-unique-jobs)
- Crontab format: [crontab.guru](https://crontab.guru)

## Support

For issues or questions:

1. Check logs: `log/sidekiq.log` and `log/production.log`
2. Review Sidekiq Web UI at `/sidekiq`
3. Check Redis: `redis-cli ping`
4. Verify systemd service: `sudo systemctl status nlims-sidekiq`
