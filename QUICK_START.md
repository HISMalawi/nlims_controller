# MLAB to NLIMS Sync - Quick Start Guide

## Prerequisites

- MLAB database dump file
- Access to nlims server
- MySQL/MariaDB installed
- Rails environment configured

## Step-by-Step Setup

### Step 1: Load MLAB Dump into Database

```bash
# Connect to MySQL
mysql -u root -p

# Create database for mlab dump
CREATE DATABASE IF NOT EXISTS mlab_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
exit

# Load the dump file
mysql -u root -p mlab_db < /path/to/your/mlab_dump.sql

# Verify it loaded
mysql -u root -p -e "USE mlab_db; SHOW TABLES; SELECT COUNT(*) FROM tests;"
```

### Step 2: Configure Database Connection

Edit `config/database.yml`:

```yaml
# Add mlab database configuration
mlab_development:
  adapter: mysql2
  encoding: utf8
  pool: 5
  host: 127.0.0.1
  port: 3306
  username: your_username
  password: your_password
  database: mlab_db

mlab_production:
  adapter: mysql2
  encoding: utf8
  pool: 5
  host: 127.0.0.1
  port: 3306
  username: <%= ENV['MLAB_DATABASE_USER'] || 'your_username' %>
  password: <%= ENV['MLAB_DATABASE_PASSWORD'] %>
  database: <%= ENV['MLAB_DATABASE_NAME'] || 'mlab_db' %>
```

### Step 3: Run Migration

```bash
cd /path/to/nlims_controller
rails db:migrate
```

This creates the `mlab_sync_failures` table.

### Step 4: Test Database Connection

```bash
rails console
```

```ruby
# Test connections
MlabTest.count
# Should return a number

MlabOrder.count
# Should return a number

# If errors occur, check your database.yml configuration
```

### Step 5: Run the Sync

```bash
bundle exec ruby bin/mlab_to_nlims_sync.rb
```

You'll be prompted for:

1. **Sending Facility**: Enter facility name (e.g., "Zomba Central Hospital") or leave blank
2. **District**: Enter district name (e.g., "Zomba") or leave blank to use 'Unknown District'
3. **Starting Test ID**: Enter 0 to start from beginning
4. **Limit**: Leave blank to process all, or enter a number for testing

Example:

```
Enter sending facility name: Zomba Central Hospital
Enter district name: Zomba
Enter starting test ID (default: 0): 0
Enter maximum number of tests to process:

Proceed with sync? (yes/no): yes
```

### Step 6: Monitor Progress

The script will show real-time progress:

```
--- Processing Batch #1 (Records 1-1000) ---
  ✓ Test ID 1: Order Created (Tracking: ZCH001)
  → Test ID 2: Skipped (already up-to-date)
  + Test ID 3: Test Added to Existing Order
  ✗ Test ID 5: FAILED - specimen type not found

Progress: 1000/5000 (20.0%)
Created: 450, Updated: 200, Skipped: 300, Failed: 50
```

### Step 7: Check for Failures (If Any)

If there were failures, investigate them:

```bash
bundle exec ruby bin/mlab_sync_failures.rb
```

This opens an interactive menu to:

- View failure summary
- See details of failures
- Mark failures as resolved
- Retry specific tests

## Common First-Time Issues

### Issue: Can't connect to mlab database

**Check:**

```bash
mysql -u your_username -p -e "USE mlab_db; SELECT 1;"
```

**Fix:** Ensure credentials in `database.yml` match your MySQL user

### Issue: "Test type not found in NLIMS"

**Cause:** Missing test types in nlims  
**Fix:** Before syncing, ensure all test types from mlab exist in nlims:

```sql
-- Find missing test types (using nlims_code from mlab)
SELECT DISTINCT tt.nlims_code, tt.name
FROM mlab_db.test_types tt
WHERE tt.nlims_code IS NOT NULL
  AND tt.nlims_code NOT IN (SELECT nlims_code FROM test_types WHERE nlims_code IS NOT NULL);
```

Add these test types to nlims before running the sync.

### Issue: "Specimen type not found"

**Cause:** Missing specimen types in nlims  
**Fix:**

```sql
-- Find missing specimen types (using nlims_code from mlab)
-- NOTE: In mlab, 'specimens' table = nlims 'specimen_types' table
SELECT DISTINCT s.nlims_code, s.name
FROM mlab_db.specimens s
WHERE s.nlims_code IS NOT NULL
  AND s.nlims_code NOT IN (SELECT nlims_code FROM specimen_types WHERE nlims_code IS NOT NULL);
```

Add these specimen types to nlims.

### Issue: "Measure not found"

**Cause:** Missing test indicators/measures in nlims  
**Fix:**

```sql
-- Find missing measures (using nlims_code from mlab)
SELECT DISTINCT ti.nlims_code, ti.name
FROM mlab_db.test_indicators ti
WHERE ti.nlims_code IS NOT NULL
  AND ti.nlims_code NOT IN (SELECT nlims_code FROM measures WHERE nlims_code IS NOT NULL);
```

Add these measures to nlims.

## Processing Multiple Site Dumps

When you have dumps from multiple sites:

### Site 1 (e.g., Zomba):

```bash
# Load first dump
mysql -u root -p mlab_db < zomba_dump.sql

# Run sync with facility name and district
bundle exec ruby bin/mlab_to_nlims_sync.rb
# Enter: Zomba Central Hospital
# District: Zomba
```

### Site 2 (e.g., Lilongwe):

```bash
# Drop and reload database
mysql -u root -p -e "DROP DATABASE mlab_db; CREATE DATABASE mlab_db;"
mysql -u root -p mlab_db < lilongwe_dump.sql

# Run sync with different facility and district
bundle exec ruby bin/mlab_to_nlims_sync.rb
# Enter: Lilongwe District Hospital
# District: Lilongwe
```

## Quick Commands Reference

```bash
# Run full sync
bundle exec ruby bin/mlab_to_nlims_sync.rb

# Manage failures interactively
bundle exec ruby bin/mlab_sync_failures.rb

# Check failure count (SQL)
mysql -u root -p nlims_db -e \
  "SELECT COUNT(*) FROM mlab_sync_failures WHERE resolved = 0;"

# Check today's synced orders
mysql -u root -p nlims_db -e \
  "SELECT COUNT(*) FROM specimen WHERE DATE(created_at) = CURDATE();"

# Rails console for debugging
rails console
```

## Test Run (Recommended)

Before processing all data, do a test run:

```bash
bundle exec ruby bin/mlab_to_nlims_sync.rb
```

When prompted:

- Sending facility: Your facility name
- District: Your district name
- Starting test ID: 0
- Limit: **50** (process only 50 records for initial test)

Review the results, check for failures, fix any issues, then run with no limit.

## Getting Help

- Check [MLAB_SYNC_README.md](./MLAB_SYNC_README.md) for detailed documentation
- Use the failure manager to investigate issues
- Check Rails logs: `tail -f log/development.log`
- Use Rails console for debugging: `rails console`

## Summary

1. ✅ Load mlab dump → `mysql`
2. ✅ Configure database.yml → Edit file
3. ✅ Run migration → `rails db:migrate`
4. ✅ Test connection → `rails console`
5. ✅ Run sync → `bundle exec ruby bin/mlab_to_nlims_sync.rb`
6. ✅ Check failures → `bundle exec ruby bin/mlab_sync_failures.rb`
7. ✅ Repeat for each site dump

Done! 🎉
