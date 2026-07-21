# DateTime Range Quick Reference

Common datetime range patterns for parallel migration processing.

## Quarterly Splits (Recommended for Yearly Data)

### Q1 2024

```
Start: 2024-01-01 00:00:00
End:   2024-03-31 23:59:59
```

### Q2 2024

```
Start: 2024-04-01 00:00:00
End:   2024-06-30 23:59:59
```

### Q3 2024

```
Start: 2024-07-01 00:00:00
End:   2024-09-30 23:59:59
```

### Q4 2024

```
Start: 2024-10-01 00:00:00
End:   2024-12-31 23:59:59
```

## Monthly Splits

### January 2024

```
Start: 2024-01-01 00:00:00
End:   2024-01-31 23:59:59
```

### February 2024

```
Start: 2024-02-01 00:00:00
End:   2024-02-29 23:59:59
```

## Weekly Splits

### Week 1 (Example)

```
Start: 2024-06-01 00:00:00
End:   2024-06-07 23:59:59
```

### Week 2

```
Start: 2024-06-08 00:00:00
End:   2024-06-14 23:59:59
```

## Daily Splits (4 instances per day)

### Instance 1: Night Shift (00:00 - 05:59)

```
Start: 2024-06-15 00:00:00
End:   2024-06-15 05:59:59
```

### Instance 2: Morning Shift (06:00 - 11:59)

```
Start: 2024-06-15 06:00:00
End:   2024-06-15 11:59:59
```

### Instance 3: Afternoon Shift (12:00 - 17:59)

```
Start: 2024-06-15 12:00:00
End:   2024-06-15 17:59:59
```

### Instance 4: Evening Shift (18:00 - 23:59)

```
Start: 2024-06-15 18:00:00
End:   2024-06-15 23:59:59
```

## 8-Hour Shifts (3 instances per day)

### Instance 1: First Shift

```
Start: 2024-06-15 00:00:00
End:   2024-06-15 07:59:59
```

### Instance 2: Second Shift

```
Start: 2024-06-15 08:00:00
End:   2024-06-15 15:59:59
```

### Instance 3: Third Shift

```
Start: 2024-06-15 16:00:00
End:   2024-06-15 23:59:59
```

## Special Use Cases

### Business Hours Only (8 AM - 5 PM)

```
Start: 2024-06-15 08:00:00
End:   2024-06-15 17:00:00
```

### Overnight Only

```
Start: 2024-06-15 18:00:00
End:   2024-06-16 07:59:59
```

### Weekend Only

```
Start: 2024-06-15 00:00:00  # Saturday
End:   2024-06-16 23:59:59  # Sunday
```

### Specific Hour

```
Start: 2024-06-15 14:00:00
End:   2024-06-15 14:59:59
```

## Tips for Choosing DateTime Ranges

1. **Check your data distribution first:**

   ```sql
   SELECT DATE(created_date) as date, COUNT(*) as count
   FROM orders
   WHERE created_date >= '2024-01-01'
   GROUP BY DATE(created_date)
   ORDER BY count DESC
   LIMIT 20;
   ```

2. **Find peak hours:**

   ```sql
   SELECT HOUR(created_date) as hour, COUNT(*) as count
   FROM orders
   WHERE DATE(created_date) = '2024-06-15'
   GROUP BY HOUR(created_date)
   ORDER BY hour;
   ```

3. **Split evenly:** Try to keep each range with similar record counts for balanced processing

4. **Avoid overlaps:** Make sure end time of one range is before start time of next

5. **Use timezone-aware times:** If your database uses UTC, adjust times accordingly

## Example: Finding Optimal Split Points

```sql
-- Count orders by month
SELECT
  DATE_FORMAT(created_date, '%Y-%m') as month,
  COUNT(*) as order_count
FROM orders
GROUP BY month
ORDER BY month;

-- Count orders by day for a specific month
SELECT
  DATE(created_date) as day,
  COUNT(*) as order_count
FROM orders
WHERE created_date BETWEEN '2024-06-01' AND '2024-06-30'
GROUP BY day
ORDER BY day;

-- Count orders by hour for a busy day
SELECT
  HOUR(created_date) as hour,
  COUNT(*) as order_count
FROM orders
WHERE DATE(created_date) = '2024-06-15'
GROUP BY hour
ORDER BY hour;
```

Use these queries to identify natural split points based on your actual data volume.
