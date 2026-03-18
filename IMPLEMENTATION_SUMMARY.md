# MLAB to NLIMS Direct Sync - Implementation Summary

## What Was Built

A comprehensive system to sync data from MLAB database dumps directly to NLIMS without using the API. This approach prevents API overload and allows for efficient bulk data migration.

## Architecture

```
┌──────────────────────┐
│  MLAB Database       │ ← Database dump loaded here
│  (Read Only)         │
└──────────┬───────────┘
           │
           │ Direct SQL Connection
           │ (Multiple DB Config)
           ▼
┌──────────────────────┐
│  NLIMS Controller    │
│  ┌────────────────┐  │
│  │ Sync Script    │  │ ← Reads from MLAB DB
│  │                │  │ ← Writes to NLIMS DB
│  │ - Build Payload│  │ ← Uses same validations as API
│  │ - Check Exists │  │ ← Prevents duplicates
│  │ - Create/Update│  │ ← Batches processing
│  │ - Track Errors │  │ ← Logs failures
│  └────────────────┘  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  NLIMS Database      │ ← Data written here
│  + Failure Tracking  │ ← Failures logged here
└──────────────────────┘
```

## Files Created

### 1. Database Configuration

- **`config/database.yml.example`** - Updated with mlab database configuration

### 2. Migration

- **`db/migrate/20260318000001_create_mlab_sync_failures.rb`** - Creates failure tracking table

### 3. Models (17 files)

#### NLIMS Models:

- **`app/models/mlab_sync_failure.rb`** - Tracks sync failures

#### MLAB Models (read from mlab database):

- **`app/models/mlab_base.rb`** - Base class connecting to mlab DB
- **`app/models/mlab_test.rb`** - Reads mlab tests
- **`app/models/mlab_order.rb`** - Reads mlab orders
- **`app/models/mlab_encounter.rb`** - Reads mlab encounters
- **`app/models/mlab_client.rb`** - Reads mlab clients
- **`app/models/mlab_person.rb`** - Reads mlab persons
- **`app/models/mlab_specimen.rb`** - Reads mlab specimens (equivalent to nlims specimen_types)
- **`app/models/mlab_test_type.rb`** - Reads mlab test types
- **`app/models/mlab_test_status.rb`** - Reads mlab test statuses
- **`app/models/mlab_status.rb`** - Reads mlab statuses
- **`app/models/mlab_test_result.rb`** - Reads mlab test results (includes unit method)
- **`app/models/mlab_test_indicator.rb`** - Reads mlab test indicators
- **`app/models/mlab_test_type_test_indicator.rb`** - Reads join table for test types and indicators (stores unit)
- **`app/models/mlab_order_status.rb`** - Reads mlab order statuses
- **`app/models/mlab_priority.rb`** - Reads mlab priorities
- **`app/models/mlab_facility.rb`** - Reads mlab facilities
- **`app/models/mlab_user.rb`** - Reads mlab users (belongs to mlab_person for names)

### 4. Scripts (2 executable files)

- **`bin/mlab_to_nlims_sync.rb`** - Main sync script (executable)
- **`bin/mlab_sync_failures.rb`** - Interactive failure manager (executable)

### 5. Documentation

- **`MLAB_SYNC_README.md`** - Complete documentation
- **`QUICK_START.md`** - Quick start guide

## Key Features Implemented

### ✅ All Requirements Met

1. **✓ Test-based sync** - Uses test table as foundation for building payloads
2. **✓ Complete payloads** - Includes order, patient, test, status, and results
3. **✓ Duplicate prevention** - Checks if order/test already exists before creating
4. **✓ Status sync** - Checks and creates missing status trail entries
5. **✓ Result sync** - Creates or updates test results using nlims_code
6. **✓ Failure tracking** - New table tracks all failed syncs with reasons
7. **✓ nlims_code identifier** - Uses nlims_code for test types and measures
8. **✓ API validations** - Uses same validation logic as API endpoints
9. **✓ Batching** - Processes 1000 records per batch (configurable)
10. **✓ Progress tracking** - Real-time progress with statistics
11. **✓ Multi-site support** - Can load different dumps and sync different facilities
12. **✓ Facility configuration** - Prompts for facility name to override data

### Sync Logic Flow

```
For each Test in MLAB (in batches of 1000):

  1. Build Payload from Test
     ├─ Extract Patient data (from person/client)
     ├─ Extract Order data (from order/encounter)
     ├─ Extract Test data (test type, status, results)
     └─ Validate required fields

  2. Check if ORDER exists (by tracking_number)
     ├─ NO  → Create New Order + Test
     └─ YES → Continue to step 3

  3. Check if TEST exists (by test_type nlims_code)
     ├─ NO  → Add Test to Order
     └─ YES → Continue to step 4

  4. Update TEST STATUS (if newer)
     ├─ Compare status trails
     └─ Add missing statuses

  5. Update TEST RESULTS (if present)
     ├─ Find measure by nlims_code
     ├─ Create new or update existing
     └─ Trail changes

  If ANY step fails:
     └─ Log to mlab_sync_failures table
```

## Usage

### First Time Setup

```bash
# 1. Load mlab dump
mysql -u root -p -e "CREATE DATABASE mlab_db;"
mysql -u root -p mlab_db < /path/to/dump.sql

# 2. Update config/database.yml with mlab credentials

# 3. Run migration
cd /path/to/nlims_controller
rails db:migrate

# 4. Test connection
rails console
> MlabTest.count
> MlabOrder.count

# 5. Run sync
bundle exec ruby bin/mlab_to_nlims_sync.rb
```

### Managing Multiple Sites

```bash
# Site 1
mysql -u root -p mlab_db < site1_dump.sql
bundle exec ruby bin/mlab_to_nlims_sync.rb
# Enter facility name when prompted

# Site 2 (reload database)
mysql -u root -p -e "DROP DATABASE mlab_db; CREATE DATABASE mlab_db;"
mysql -u root -p mlab_db < site2_dump.sql
bundle exec ruby bin/mlab_to_nlims_sync.rb
# Enter different facility name

# Continue for each site...
```

### Investigating Failures

```bash
# Interactive manager
bundle exec ruby bin/mlab_sync_failures.rb

# Or SQL
mysql -u root -p nlims_db -e \
  "SELECT * FROM mlab_sync_failures WHERE resolved = 0 LIMIT 10;"
```

## Data Validation

The sync uses the same validation as the API:

- ✓ Required fields checked (patient name, DOB, tracking number, etc.)
- ✓ Test types must exist in NLIMS (by nlims_code)
- ✓ Specimen types must exist in NLIMS
- ✓ Measures must be linked to test types
- ✓ Status names mapped correctly
- ✓ Date formats validated

## Performance

- **Batch Size**: 1000 records (configurable)
- **Memory Efficient**: Processes in batches, not all at once
- **Progress Tracking**: Real-time statistics
- **Failure Recovery**: Can resume from any test ID
- **Idempotent**: Safe to run multiple times

## Safety Features

1. **No Data Loss**: Existing data is never deleted or overwritten incorrectly
2. **Duplicate Prevention**: Checks prevent duplicate orders/tests
3. **Status Trail Preservation**: Existing status entries not duplicated
4. **Result Versioning**: Updates tracked in result trails
5. **Comprehensive Logging**: All failures logged with full context
6. **Rollback Safe**: Uses transactions where possible

## Monitoring

### Real-time (during sync)

```
Progress: 5000/10000 (50.0%)
Created: 2000, Updated: 1500, Skipped: 1400, Failed: 100
```

### Post-sync Analysis

```sql
-- Count synced today
SELECT COUNT(*) FROM specimen WHERE DATE(created_at) = CURDATE();

-- Failure analysis
SELECT failure_stage, COUNT(*)
FROM mlab_sync_failures
WHERE resolved = 0
GROUP BY failure_stage;
```

## Next Steps

1. **Setup**: Follow QUICK_START.md
2. **Test Run**: Process first 100 records to verify
3. **Full Sync**: Run without limit for complete migration
4. **Fix Failures**: Use failure manager to investigate and resolve
5. **Repeat**: Load next site dump and repeat

## Support Resources

- **Complete Docs**: [MLAB_SYNC_README.md](MLAB_SYNC_README.md)
- **Quick Start**: [QUICK_START.md](QUICK_START.md)
- **Failure Manager**: `bundle exec ruby bin/mlab_sync_failures.rb`
- **Rails Console**: For debugging and manual fixes

## Success Metrics

After a successful sync, you should see:

✅ Orders created in NLIMS with correct tracking numbers  
✅ Tests associated with orders  
✅ Status trails properly recorded  
✅ Test results synced (where available)  
✅ Minimal failures (or all failures resolved)  
✅ Data matches MLAB source

## Maintenance

- Check failures regularly
- Resolve common issues (missing test types, specimens)
- Update facility mappings as needed
- Monitor database disk space
- Archive old sync failure logs

---

**Created**: March 18, 2026  
**Purpose**: Bulk MLAB to NLIMS migration without API overhead  
**Status**: Ready for use ✅
