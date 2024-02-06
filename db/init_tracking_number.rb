todate = Time.now.strftime('%Y%m%d')
last_tracking_number_trail = TrackingNumberTrail.last
puts last_tracking_number_trail
begin
  file = JSON.parse(File.read("#{Rails.root}/public/tracker.json"))
  value = file[todate]
  if value.nil? && last_tracking_number_trail.nil?
    TrackingNumberTrail.create(date: todate, current_value: 1)
  elsif last_tracking_number_trail.nil?
    TrackingNumberTrail.create(date: todate, current_value: value.to_i)
  end
rescue StandardError => _e
  TrackingNumberTrail.create(date: todate, current_value: 1) if last_tracking_number_trail.nil?
end
