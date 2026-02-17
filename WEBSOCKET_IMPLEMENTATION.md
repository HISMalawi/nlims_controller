# WebSocket Order Updates Implementation

## Overview

This implementation adds real-time WebSocket broadcasts for order updates, specifically for:

1. **Status Updates** - When test status changes (e.g., specimen_collected, testing, verified)
2. **Result Updates** - When test results are added or updated

## Components Created

### 1. OrdersChannel (`app/channels/orders_channel.rb`)

WebSocket channel for broadcasting order updates to connected clients.

**Features:**

- Subscribe to all orders: `orders`
- Subscribe to specific tracking number: `orders:{tracking_number}`

**Example Client Connection (JavaScript):**

```javascript
// Subscribe to all orders
const ordersChannel = consumer.subscriptions.create("OrdersChannel", {
  received(data) {
    console.log("Order update:", data);
    // Handle update: data.type will be 'status_update', 'result_update', or 'order_status_update'
    // data.data contains the full order payload
  },
});

// Subscribe to specific tracking number
const specificOrderChannel = consumer.subscriptions.create(
  { channel: "OrdersChannel", tracking_number: "ABC123" },
  {
    received(data) {
      console.log("Order ABC123 update:", data);
    },
  },
);
```

### 2. OrderBroadcastService (`app/services/order_broadcast_service.rb`)

Service class for broadcasting order updates via WebSocket.

**Methods:**

- `broadcast_status_update(test_id)` - Broadcast test status changes
- `broadcast_result_update(test_id)` - Broadcast test result updates
- `broadcast_order_status_update(order_id)` - Broadcast specimen status changes

**Broadcast Channels:**

- `orders` - General channel for all order updates
- `orders:{tracking_number}` - Specific channel for individual orders

### 3. Integration Points

Broadcasts are triggered from the core service classes where updates actually occur:

**TestsService** (`app/services/TestManagement/tests_service.rb`):

- `update_tests` - Broadcasts status updates after test status changes
- `add_test_results` - Broadcasts result updates when results are added or updated

**OrdersService** (`app/services/OrderManagement/orders_service.rb`):

- `update_order` - Broadcasts order status updates after specimen status changes

## Broadcast Payload Structure

All broadcasts follow this structure:

```json
{
  "type": "status_update|result_update|order_status_update",
  "timestamp": "2026-02-17T10:30:45Z",
  "data": {
    "order": {
      "uuid": "couch_id",
      "tracking_number": "ABC123",
      "sample_type": "Blood",
      "sample_status": "verified",
      "order_location": "Ward Name",
      "date_created": "2026-02-15T10:00:00Z",
      "priority": "High",
      "reason_for_test": "Routine",
      "drawn_by": {
        "id": 1,
        "name": "John Doe",
        "phone_number": "+265..."
      },
      "target_lab": "Central Lab",
      "sending_facility": "Facility Name",
      "district": "District Name",
      "site_code_number": "12345",
      "requested_by": "Dr. Smith",
      "art_start_date": "2020-01-01",
      "arv_number": "ARV123",
      "art_regimen": "TDF/3TC/DTG",
      "clinical_history": "Patient history...",
      "lab_location": "Lab Location",
      "source_system": "EMR",
      "status_trail": [
        {
          "status_id": 1,
          "status": "specimen_collected",
          "timestamp": "2026-02-15T10:00:00Z",
          "updated_by": {
            "first_name": "John",
            "last_name": "Doe",
            "id": 1,
            "phone_number": "+265..."
          }
        }
      ]
    },
    "patient": {
      "id": 1,
      "national_patient_id": "NID123",
      "first_name": "Jane",
      "last_name": "Doe",
      "gender": "F",
      "date_of_birth": "1990-01-01",
      "address": "Address...",
      "email": "jane@example.com",
      "phone_number": "+265..."
    },
    "tests": [
      {
        "id": 1,
        "test_type": "Viral Load",
        "test_status": "verified",
        "created_date": "2026-02-15T10:00:00Z",
        "result": {
          "result_type": "numeric",
          "result_value": "1000",
          "result_date": "2026-02-16T15:00:00Z"
        },
        "test_status_trail": [...]
      }
    ]
  }
}
```

## When Broadcasts Occur

### Status Updates

Triggered when:

- Test status changes (specimen_collected → testing → verified)
- Via `TestManagement::TestsService.update_tests`
- Called when test status is updated through the API or internal processes

### Result Updates

Triggered when:

- Test results are added or updated
- Via `TestManagement::TestsService.add_test_results`
- Called when new results are created or existing results are modified

### Order Status Updates

Triggered when:

- Specimen/order status changes
- Via `OrderManagement::OrdersService.update_order`
- Called when order status transitions through different stages

## Testing WebSocket Broadcasts

### 1. Rails Console Test

```ruby
# Test status update broadcast
OrderBroadcastService.broadcast_status_update(test_id)

# Test result update broadcast
OrderBroadcastService.broadcast_result_update(test_id)

# Test order status update broadcast
OrderBroadcastService.broadcast_order_status_update(order_id)
```

### 2. JavaScript Client Test

```javascript
// In browser console with Action Cable
import consumer from "./consumer";

const channel = consumer.subscriptions.create("OrdersChannel", {
  connected() {
    console.log("Connected to OrdersChannel");
  },

  disconnected() {
    console.log("Disconnected from OrdersChannel");
  },

  received(data) {
    console.log("Received:", data);

    switch (data.type) {
      case "status_update":
        console.log("Test status updated:", data.data.tests);
        break;
      case "result_update":
        console.log("Test result updated:", data.data.tests);
        break;
      case "order_status_update":
        console.log("Order status updated:", data.data.order.sample_status);
        break;
    }
  },
});
```

### 3. WebSocket CLI Test (using wscat)

```bash
# Install wscat
npm install -g wscat

# Connect to WebSocket
wscat -c ws://localhost:3000/cable

# Subscribe to channel
{"command":"subscribe","identifier":"{\"channel\":\"OrdersChannel\"}"}

# Subscribe to specific tracking number
{"command":"subscribe","identifier":"{\"channel\":\"OrdersChannel\",\"tracking_number\":\"ABC123\"}"}
```

## Configuration

### Action Cable is Already Configured ✓

Action Cable is mounted at `/cable` in `config/routes.rb`:

```ruby
mount ActionCable.server => '/cable'
```

### Development Environment

The development environment is configured to allow WebSocket connections from any origin:

**config/environments/development.rb:**

```ruby
# Disable request forgery protection to allow connections from any origin
config.action_cable.disable_request_forgery_protection = true
```

This allows you to connect from:

- Browser extensions (like wscat)
- Local HTML files
- Frontend apps running on different ports
- Testing tools

### Production Environment

For production, configure specific allowed origins for security:

**config/environments/production.rb:**

```ruby
# Configure allowed request origins for production WebSocket connections
config.action_cable.allowed_request_origins = [
  ENV.fetch('FRONTEND_URL', 'http://localhost:3000'),
  /http:\/\/localhost:.*/,
  /https:\/\/.*\.yourdomain\.com/
]
```

Update the regex patterns with your actual domain(s).

### Cable Configuration

**config/cable.yml:**

```yaml
development:
  adapter: redis
  url: redis://localhost:6379/1

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: nlims_controller_production
```

## Testing Tools

### 1. Browser-Based Test (Recommended)

Open the built-in test page:

```
http://localhost:3009/websocket_test.html
```

Features:

- Visual WebSocket connection status
- Subscribe to all orders or specific tracking numbers
- Real-time message logging
- Statistics dashboard
- JSON payload viewer

### 2. Command Line Test (wscat)

Install wscat:

```bash
npm install -g wscat
```

Connect and subscribe:

```bash
# Connect to WebSocket
wscat -c ws://localhost:3009/cable

# Subscribe to all orders
{"command":"subscribe","identifier":"{\"channel\":\"OrdersChannel\"}"}

# Subscribe to specific tracking number
{"command":"subscribe","identifier":"{\"channel\":\"OrdersChannel\",\"tracking_number\":\"ABC123\"}"}
```

### 3. Rails Console Test

```ruby
# Test status update broadcast
OrderBroadcastService.broadcast_status_update(test_id)

# Test result update broadcast
OrderBroadcastService.broadcast_result_update(test_id)

# Test order status update broadcast
OrderBroadcastService.broadcast_order_status_update(order_id)
```

## Monitoring

### Check Active Connections

```ruby
# In Rails console
ActionCable.server.connections.count
ActionCable.server.pubsub.channels
```

### View Logs

```bash
# WebSocket connections and broadcasts logged to
tail -f log/development.log
tail -f log/production.log

# Look for:
# [OrderBroadcastService] Broadcasted status update for tracking_number: ABC123
# [OrderBroadcastService] Broadcasted result update for tracking_number: ABC123
```

## Performance Considerations

1. **Broadcast Channels**: Each order broadcasts to 2 channels:
   - General `orders` channel
   - Specific `orders:{tracking_number}` channel

2. **Payload Size**: Full order payload (~1-5KB per broadcast)

3. **Redis**: Uses Redis for pub/sub (ensure Redis has sufficient memory)

4. **Concurrency**: Broadcasts are non-blocking and won't slow down sync operations

## Error Handling

All broadcasts include error handling:

- Errors logged to Rails logger
- Failed broadcasts don't block sync operations
- Backtrace included in error logs

## Client Implementation Example

### React/JavaScript Subscription

```javascript
import consumer from "./channels/consumer";

class OrderMonitor {
  constructor() {
    this.subscription = null;
  }

  subscribeToAll() {
    this.subscription = consumer.subscriptions.create("OrdersChannel", {
      connected: () => console.log("Connected to orders"),
      disconnected: () => console.log("Disconnected from orders"),
      received: (data) => this.handleUpdate(data),
    });
  }

  subscribeToTrackingNumber(trackingNumber) {
    this.subscription = consumer.subscriptions.create(
      { channel: "OrdersChannel", tracking_number: trackingNumber },
      {
        connected: () => console.log(`Connected to ${trackingNumber}`),
        received: (data) => this.handleUpdate(data),
      },
    );
  }

  handleUpdate(data) {
    console.log(`Update type: ${data.type}`);
    console.log(`Tracking: ${data.data.order.tracking_number}`);
    console.log(`Status: ${data.data.order.sample_status}`);
    console.log(`Tests:`, data.data.tests);

    // Update UI
    this.updateOrderUI(data.data);
  }

  updateOrderUI(orderData) {
    // Your UI update logic here
  }

  unsubscribe() {
    if (this.subscription) {
      this.subscription.unsubscribe();
    }
  }
}

// Usage
const monitor = new OrderMonitor();
monitor.subscribeToAll(); // All orders
// or
monitor.subscribeToTrackingNumber("ABC123"); // Specific order
```

## Troubleshooting

### "Request origin not allowed" Error

**Problem:** WebSocket connection fails with:

```
Request origin not allowed:
Failed to upgrade to WebSocket
```

**Solution:**

For **development**, ensure origin protection is disabled in `config/environments/development.rb`:

```ruby
config.action_cable.disable_request_forgery_protection = true
```

For **production**, add your frontend domain to allowed origins in `config/environments/production.rb`:

```ruby
config.action_cable.allowed_request_origins = [
  'https://your-frontend-domain.com',
  /https:\/\/.*\.yourdomain\.com/
]
```

After making changes, **restart the Rails server**.

### WebSocket not connecting

1. Restart Rails server after configuration changes
2. Check Redis is running: `redis-cli ping`
3. Verify server is binding to correct interface: `rails s -p 3009 -b 0.0.0.0`
4. Check cable.yml configuration
5. Verify Action Cable is mounted in routes: `mount ActionCable.server => '/cable'`
6. Test with browser-based tool: `http://localhost:3009/websocket_test.html`

### Broadcasts not received

1. Check client is subscribed: `ActionCable.server.connections`
2. Check logs for broadcast confirmation
3. Verify OrderBroadcastService is being called
4. Test broadcast manually from console
5. Ensure subscription identifier is correct

### Performance issues

1. Monitor Redis memory usage
2. Consider implementing broadcast throttling
3. Use specific tracking number subscriptions instead of general channel
4. Monitor WebSocket connection count
5. Check for message queuing/backlog

### Connection drops frequently

1. Check network stability
2. Implement client-side reconnection logic
3. Monitor server resources (CPU, memory)
4. Check Redis connection stability
5. Consider increasing Action Cable worker pool size

## Next Steps

To fully integrate with a frontend:

1. **Setup Action Cable Consumer** in your frontend app
2. **Subscribe to OrdersChannel** on relevant pages
3. **Handle updates** in UI (update tables, show notifications, etc.)
4. **Add authentication** to WebSocket connections if needed
5. **Implement reconnection logic** for dropped connections

Refer to Rails Action Cable documentation: https://guides.rubyonrails.org/action_cable_overview.html
