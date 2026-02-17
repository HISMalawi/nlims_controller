# WebSocket Quick Start Guide

## 🚀 Quick Start

### 1. Start the Server

```bash
rails s -p 3009 -b 0.0.0.0
```

### 2. Test the Connection

**Option A: Browser Test (Easiest)**

```
Open: http://localhost:3009/websocket_test.html
Click "Connect" → "Subscribe to Orders"
```

**Option B: Command Line (wscat)**

```bash
# Install wscat (once)
npm install -g wscat

# Connect
wscat -c ws://localhost:3009/cable

# Subscribe to all orders
{"command":"subscribe","identifier":"{\"channel\":\"OrdersChannel\"}"}

# Subscribe to specific order
{"command":"subscribe","identifier":"{\"channel\":\"OrdersChannel\",\"tracking_number\":\"ABC123\"}"}
```

**Option C: Rails Console**

```ruby
rails console

# Test broadcasting
OrderBroadcastService.broadcast_status_update(test_id)
OrderBroadcastService.broadcast_result_update(test_id)
OrderBroadcastService.broadcast_order_status_update(order_id)
```

## 📡 WebSocket URL

**Development:** `ws://localhost:3009/cable`
**Production:** `wss://your-domain.com/cable` (use wss:// for SSL)

## 📢 Broadcast Types

| Type                  | Triggered By                  | Payload Contains          |
| --------------------- | ----------------------------- | ------------------------- |
| `status_update`       | Test status changes           | Full order + test data    |
| `result_update`       | Test results added/updated    | Full order + test results |
| `order_status_update` | Order/specimen status changes | Full order + status trail |

## 🔌 Subscribe to Channel

### All Orders

```json
{
  "command": "subscribe",
  "identifier": "{\"channel\":\"OrdersChannel\"}"
}
```

### Specific Tracking Number

```json
{
  "command": "subscribe",
  "identifier": "{\"channel\":\"OrdersChannel\",\"tracking_number\":\"ABC123\"}"
}
```

## 📦 Message Format

```json
{
  "type": "status_update|result_update|order_status_update",
  "timestamp": "2026-02-17T10:30:45Z",
  "data": {
    "order": {
      /* order details */
    },
    "patient": {
      /* patient details */
    },
    "tests": [
      /* test array */
    ]
  }
}
```

## 🐛 Common Issues

### "Request origin not allowed"

**Fix:** Restart Rails server (configuration was updated)

### WebSocket won't connect

```bash
# Check Redis is running
redis-cli ping

# Should return: PONG
```

### Not receiving broadcasts

```bash
# Test from Rails console
rails console
> OrderBroadcastService.broadcast_status_update(Test.first.id)
```

## 📝 Integration Example (JavaScript)

```javascript
// Connect
const ws = new WebSocket("ws://localhost:3009/cable");

// Handle connection
ws.onopen = () => {
  console.log("Connected!");

  // Subscribe to all orders
  ws.send(
    JSON.stringify({
      command: "subscribe",
      identifier: JSON.stringify({ channel: "OrdersChannel" }),
    }),
  );
};

// Handle messages
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);

  if (data.message) {
    console.log("Update:", data.message.type);
    console.log("Order:", data.message.data.order);

    // Update your UI here
    updateOrderUI(data.message.data);
  }
};

// Handle errors
ws.onerror = (error) => {
  console.error("WebSocket error:", error);
};
```

## 🔗 Useful URLs

- **Test Page:** http://localhost:3009/websocket_test.html
- **Sidekiq Dashboard:** http://localhost:3009/sidekiq
- **API Docs:** http://localhost:3009/api-docs

## 📚 Full Documentation

See [WEBSOCKET_IMPLEMENTATION.md](WEBSOCKET_IMPLEMENTATION.md) for complete documentation.

## ⚙️ Configuration Files

- **Development:** `config/environments/development.rb`
- **Production:** `config/environments/production.rb`
- **Cable:** `config/cable.yml`
- **Routes:** `config/routes.rb` (mounts `/cable`)

## 🎯 When Broadcasts Happen

✅ **Automatically** when:

- Tests are updated via API
- Results are added/modified
- Order statuses change
- Data is synced from external systems

The broadcasts happen in:

- `TestManagement::TestsService` (status & result updates)
- `OrderManagement::OrdersService` (order status updates)

## 💡 Tips

1. Use browser test page for quick verification
2. Subscribe to specific tracking numbers to reduce noise
3. Monitor broadcasts in Rails logs
4. Test with `rails r bin/test_websocket_broadcasts.rb`
5. Use Sidekiq dashboard to monitor job processing

## 🆘 Need Help?

Check the logs:

```bash
tail -f log/development.log
tail -f log/sidekiq.log
```

Look for:

```
[OrderBroadcastService] Broadcasted status update for tracking_number: ABC123
```
