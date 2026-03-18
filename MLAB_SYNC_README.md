# MLAB to NLIMS Data Sync System

## Overview

This system allows you to sync data from mlab database dumps directly to nlims without overloading the API. The sync script runs within nlims_controller and connects to both the nlims database (for writing) and the mlab database (for reading).

## 🚀 Quick Start

```bash
# 1. Load mlab dump
mysql -u root -p -e "CREATE DATABASE mlab_db;"
mysql -u root -p mlab_db < mlab_dump.sql

# 2. Update database.yml with mlab credentials

# 3. Run migration
rails db:migrate

# 4. Run sync
bundle exec ruby bin/mlab_to_nlims_sync.rb

# 5. Check failures (if any)
bundle exec ruby bin/mlab_sync_failures.rb
```

## Architecture

```
┌─────────────────┐
│  MLAB Database  │  (Loaded dump - Read Only)
│   (Source)      │
└────────┬────────┘
         │
         │ Direct DB Connection
         │
    ┌────▼──────────────────────┐
    │  NLIMS Controller         │
    │  - Reads from mlab DB     │
    │  - Writes to nlims DB     │
    │  - Tracks failures        │
    └───────────────────────────┘
         │
         │
    ┌────▼──────────────────────┐
    │   NLIMS Database          │
    │   (Destination)           │
    └───────────────────────────┘
```

## Setup Instructions

### 1. Load MLAB Database Dump

First, load your mlab database dump onto the nlims server:

```bash
# Create mlab database
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS mlab_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Load the dump
mysql -u root -p mlab_db < /path/to/mlab_dump.sql

# Verify
mysql -u root -p -e "USE mlab_db; SHOW TABLES; SELECT COUNT(*) FROM tests;"
```

### 2. Configure Database Connection

Update `config/database.yml` with your mlab database credentials:

```yaml
development:
  <<: *default
  database: lims_db

# mlab database connection (read-only for sync purposes)
mlab_development:
  <<: *default
  database: mlab_db
  username: your_username
  password: your_password

production:
  <<: *default
  database: nlims_production
  username: nlims
  password: <%= ENV['NLIMS_DATABASE_PASSWORD'] %>

mlab_production:
  <<: *default
  database: <%= ENV['MLAB_DATABASE_NAME'] || 'mlab_production' %>
  username: <%= ENV['MLAB_DATABASE_USER'] || 'nlims' %>
  password: <%= ENV['MLAB_DATABASE_PASSWORD'] %>
```

### 3. Run Migrations

Run the migration to create the failure tracking table:

```bash
cd /path/to/nlims_controller
rails db:migrate
```

This creates the `mlab_sync_failures` table to track any sync errors.

### 4. Verify Database Connection

Test that nlims can connect to the mlab database:

```bash
rails console
```

```ruby
# Test mlab database connection
MlabTest.count
MlabOrder.count
MlabPerson.count

# Should return counts without errors
```

## Running the Sync

### Basic Usage

```bash
cd /path/to/nlims_controller
bundle exec ruby bin/mlab_to_nlims_sync.rb
```

The script will prompt you for:

1. **Sending Facility** - Override the facility name for all records, or leave blank to use data from mlab
2. **Starting Test ID** - Start syncing from a specific test ID (useful for resuming)
3. **Limit** - Maximum number of tests to process (leave blank for all)

### Example Session

```bash
$ bundle exec ruby bin/mlab_to_nlims_sync.rb

MLAB to NLIMS Sync Script

Enter sending facility name (leave blank to use facility from mlab data): Zomba Central Hospital
Enter starting test ID (default: 0): 0
Enter maximum number of tests to process (leave blank for all): 5000

Configuration:
  Sending Facility: Zomba Central Hospital
  Starting from Test ID: 0
  Limit: 5000

Proceed with sync? (yes/no): yes

================================================================================
MLAB TO NLIMS DATA SYNC
================================================================================
Start Time: 2026-03-18 10:30:00 +0200
Sending Facility: Zomba Central Hospital
Starting from Test ID: 0
Batch Size: 1000
================================================================================

Total tests to sync: 5000

--- Processing Batch #1 (Records 1-1000) ---
  ✓ Test ID 1: Order Created (Tracking: ZCH001)
  → Test ID 2: Skipped (already up-to-date)
  + Test ID 3: Test Added to Existing Order (NLIMS Test ID: 1523)
  ↻ Test ID 4: Updated (NLIMS Test ID: 1234)
  ✗ Test ID 5: Order Creation FAILED - specimen type not found
  ...

Progress: 1000/5000 (20.0%)
Created: 450, Updated: 200, Skipped: 300, Failed: 50
...
```

### Resume from Specific Test ID

If the sync is interrupted, you can resume from where it stopped:

```bash
$ bundle exec ruby bin/mlab_to_nlims_sync.rb

Enter sending facility name: Zomba Central Hospital
Enter starting test ID (default: 0): 15000
Enter maximum number of tests to process:
```

### Process Specific Site Data

When loading a new site's dump:

1. Load the new dump into the mlab database:

   ```bash
   mysql -u root -p -e "DROP DATABASE IF EXISTS mlab_db;"
   mysql -u root -p -e "CREATE DATABASE mlab_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
   mysql -u root -p mlab_db < /path/to/new_site_dump.sql
   ```

2. Run the sync with the correct facility name:
   ```bash
   bundle exec ruby bin/mlab_to_nlims_sync.rb
   # When prompted, enter the correct facility name
   ```

## Features

### ✅ What the Script Does

1. **Processes in Batches** - Handles 1000 records at a time to avoid memory issues
2. **Checks for Existing Data** - Prevents duplicate orders and tests
3. **Updates Existing Records** - Updates statuses and results if newer data is available
4. **Tracks Failures** - Logs all failures to `mlab_sync_failures` table for investigation
5. **Shows Progress** - Real-time progress updates with statistics
6. **Validates Data** - Uses the same validations as the API endpoints
7. **Maps Statuses** - Automatically maps mlab status names to nlims status names
8. **Handles Results** - Syncs test results using nlims_code for measures

### 🔄 Sync Logic

For each test in mlab:

1. **Check if ORDER exists** (by tracking_number)
   - If NO → Create new order with all tests
   - If YES → Continue to step 2

2. **Check if TEST exists** for that order (by test_type nlims_code)
   - If NO → Add test to existing order
   - If YES → Continue to step 3

3. **Check if STATUS needs update**
   - Compare status trails
   - Add new statuses that don't exist

4. **Check if RESULTS need update**
   - Compare results by measure nlims_code
   - Create new results or update existing ones

## Monitoring & Troubleshooting

### Using the Failure Manager (Interactive)

The easiest way to manage failures is using the interactive failure manager:

```bash
bundle exec ruby bin/mlab_sync_failures.rb
```

This provides a menu-driven interface to:

1. **Show Failure Summary** - Quick overview of all failures
2. **Show Failures by Stage** - Group failures by where they occurred
3. **Show Recent Failures** - Last 50 unresolved failures
4. **Search by Tracking Number** - Find failures for specific orders
5. **Show Failure Details** - Full details including payload
6. **Mark Failures as Resolved** - Bulk or individual resolution
7. **Export Failed Test IDs** - Export to file for batch processing
8. **Retry Specific Test** - Re-run sync for a single test

### Check Sync Failures (SQL)

```sql
-- All unresolved failures
SELECT * FROM mlab_sync_failures
WHERE resolved = 0
ORDER BY created_at DESC;

-- Failures by stage
SELECT failure_stage, COUNT(*) as count
FROM mlab_sync_failures
WHERE resolved = 0
GROUP BY failure_stage;

-- Failures by site
SELECT site_name, COUNT(*) as count
FROM mlab_sync_failures
WHERE resolved = 0
GROUP BY site_name;

-- Failures for specific tracking number
SELECT * FROM mlab_sync_failures
WHERE tracking_number = 'YOUR_TRACKING_NUMBER';

-- Failures for specific site
SELECT * FROM mlab_sync_failures
WHERE site_name = 'YOUR_SITE_NAME' AND resolved = 0;
```

### Mark Failures as Resolved (Rails Console)

```ruby
# In Rails console
failure = MlabSyncFailure.find(ID)
failure.mark_resolved!(user_id, "Fixed by ...")

# Or bulk resolve
MlabSyncFailure.where(failure_stage: 'order_creation')
               .where("failure_reason LIKE '%specimen type not found%'")
               .each { |f| f.mark_resolved!(1, "Specimen types added") }
```

### Retry Failed Records

To retry specific test IDs:

```bash
# Create a list of failed test IDs
mysql -u root -p nlims_db -e \
  "SELECT DISTINCT mlab_test_id FROM mlab_sync_failures WHERE resolved = 0" \
  > failed_ids.txt

# Then manually process or update the script to target these IDs
```

### Check Sync Progress

```sql
-- Orders created today
SELECT COUNT(*) FROM specimen
WHERE DATE(created_at) = CURDATE();

-- Tests created today
SELECT COUNT(*) FROM tests
WHERE DATE(created_at) = CURDATE();

-- Tests by status
SELECT ts.name, COUNT(*) as count
FROM tests t
JOIN test_statuses ts ON ts.id = t.test_status_id
WHERE DATE(t.created_at) = CURDATE()
GROUP BY ts.name;
```

## Common Issues & Solutions

### Issue: "Test type not found in NLIMS"

**Problem**: The mlab test_type has an nlims_code that doesn't exist in nlims.

**Solution**:

```sql
-- Find missing test types
SELECT DISTINCT tt.nlims_code, tt.name
FROM mlab_db.test_types tt
WHERE tt.nlims_code NOT IN (SELECT nlims_code FROM test_types);

-- Add missing test types to nlims or map them
```

### Issue: "Specimen type not found in NLIMS"

**Problem**: The mlab specimen type doesn't exist in nlims.

**Solution**:

```sql
-- Find missing specimen types (by nlims_code)
-- NOTE: In mlab, 'specimens' table = nlims 'specimen_types' table
SELECT DISTINCT s.nlims_code, s.name
FROM mlab_db.specimens s
WHERE s.nlims_code IS NOT NULL
  AND s.nlims_code NOT IN (SELECT nlims_code FROM specimen_types WHERE nlims_code IS NOT NULL);

-- Add missing specimen types to nlims
```

### Issue: "Measure not found for test type"

**Problem**: Test results reference measures not linked to the test type.

**Solution**:

```ruby
# In Rails console - link measure to test type
test_type = TestType.find_by(nlims_code: 'NLIMS_TT_XXXX_MWI')
measure = Measure.find_by(nlims_code: 'NLIMS_TI_XXXX_MWI')
TesttypeMeasure.create!(test_type: test_type, measure: measure)
```

### Issue: Database connection errors

**Problem**: Cannot connect to mlab database.

**Solution**:

1. Verify database credentials in `database.yml`
2. Check database exists: `mysql -u root -p -e "SHOW DATABASES;"`
3. Check user permissions: `GRANT ALL ON mlab_db.* TO 'your_user'@'localhost';`

## Performance Tips

### For Large Datasets

1. **Run during off-peak hours** - Reduces load on the system
2. **Process in chunks** - Use the limit parameter to process manageable chunks
3. **Monitor disk space** - Ensure adequate space for both databases
4. **Index optimization** - The mlab database should have indices on:
   - `tests.id`
   - `tests.order_id`
   - `tests.test_type_id`
   - `tests.voided`
   - `orders.tracking_number`

### Batch Size Tuning

The default batch size is 1000. You can adjust it in the script:

```ruby
# In bin/mlab_to_nlims_sync.rb
BATCH_SIZE = 500  # Reduce for lower memory usage
BATCH_SIZE = 2000 # Increase for faster processing
```

## Data Integrity

### Validation

The script uses the same validation logic as the API:

- Required fields are checked
- Data formats are validated
- Status names are mapped correctly
- nlims_code is used for all lookups

**Important:** All lookups use `nlims_code` from mlab for accurate matching:

- `test_types.nlims_code` → matches NLIMS test_types
- `specimens.nlims_code` → matches NLIMS specimen_types (note: mlab "specimens" = nlims "specimen_types")
- `test_indicators.nlims_code` → matches NLIMS measures

This ensures data consistency and prevents mismatches between systems.

### Idempotency

The script is idempotent - you can run it multiple times safely:

- Existing orders are NOT duplicated
- Existing tests are NOT duplicated
- Status trails are NOT duplicated
- Results are updated only if different

## Files Created

```
nlims_controller/
├── bin/
│   └── mlab_to_nlims_sync.rb          # Main sync script
├── app/
│   └── models/
│       ├── mlab_base.rb                # Base class for mlab models
│       ├── mlab_test.rb                # mlab test model
│       ├── mlab_order.rb               # mlab order model
│       ├── mlab_encounter.rb           # mlab encounter model
│       ├── mlab_client.rb              # mlab client model
│       ├── mlab_person.rb              # mlab person model
│       ├── mlab_specimen.rb            # mlab specimen model
│       ├── mlab_test_type.rb           # mlab test type model
│       ├── mlab_test_status.rb         # mlab test status model
│       ├── mlab_status.rb              # mlab status model
│       ├── mlab_test_result.rb         # mlab test result model
│       ├── mlab_test_indicator.rb      # mlab test indicator model
│       ├── mlab_order_status.rb        # mlab order status model
│       ├── mlab_priority.rb            # mlab priority model
│       ├── mlab_facility.rb            # mlab facility model
│       └── mlab_sync_failure.rb        # Failure tracking model
├── db/
│   └── migrate/
│       └── 20260318000001_create_mlab_sync_failures.rb
└── config/
    └── database.yml.example            # Updated with mlab config
```

## Support

For issues or questions:

1. Check the `mlab_sync_failures` table for error details
2. Review the script output for specific error messages
   3.Run validations in Rails console to test individual records
3. Check database connectivity and permissions
