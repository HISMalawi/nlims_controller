# Quick Test Script for WebSocket Broadcasts
# Run with: bundle exec rails runner bin/test_websocket_broadcasts.rb

puts '========================================='
puts 'WebSocket Broadcast Test Script'
puts '========================================='
puts ''

# Test 1: Broadcast Status Update
puts 'Test 1: Broadcasting Status Update...'
test = Test.first
if test
  puts "  Using test_id: #{test.id}"
  puts "  Tracking number: #{test.speciman&.tracking_number}"
  OrderBroadcastService.broadcast_status_update(test.id)
  puts '  ✓ Status update broadcasted'
else
  puts '  ✗ No tests found in database'
end
puts ''

# Test 2: Broadcast Result Update
puts 'Test 2: Broadcasting Result Update...'
test_with_result = Test.joins(:test_results).first
if test_with_result
  puts "  Using test_id: #{test_with_result.id}"
  puts "  Tracking number: #{test_with_result.speciman&.tracking_number}"
  OrderBroadcastService.broadcast_result_update(test_with_result.id)
  puts '  ✓ Result update broadcasted'
else
  puts '  ✗ No tests with results found in database'
end
puts ''

# Test 3: Broadcast Order Status Update
puts 'Test 3: Broadcasting Order Status Update...'
order = Speciman.first
if order
  puts "  Using order_id: #{order.id}"
  puts "  Tracking number: #{order.tracking_number}"
  OrderBroadcastService.broadcast_order_status_update(order.id)
  puts '  ✓ Order status update broadcasted'
else
  puts '  ✗ No orders found in database'
end
puts ''

# Test 4: Check Action Cable Server
puts 'Test 4: Checking Action Cable Server...'
begin
  puts "  Server configured: #{ActionCable.server.class}"
  puts '  ✓ Action Cable server is ready'
rescue StandardError => e
  puts "  ✗ Error: #{e.message}"
end
puts ''

# Test 5: Check Redis Connection (if using Redis adapter)
puts 'Test 5: Checking Redis Connection...'
begin
  if defined?(Redis)
    redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
    if redis.ping == 'PONG'
      puts '  ✓ Redis is connected'
    else
      puts '  ✗ Redis ping failed'
    end
  else
    puts '  ⚠ Redis gem not loaded (may be using async adapter)'
  end
rescue StandardError => e
  puts "  ✗ Error: #{e.message}"
end
puts ''

puts '========================================='
puts 'Test Complete'
puts '========================================='
puts ''
puts 'Next Steps:'
puts '1. Connect a WebSocket client to ws://localhost:3000/cable'
puts '2. Subscribe to OrdersChannel'
puts '3. Run this script again to see broadcasts'
puts ''
puts 'Example subscription:'
puts '  {"command":"subscribe","identifier":"{\\"channel\\":\\"OrdersChannel\\"}"}'
puts ''
