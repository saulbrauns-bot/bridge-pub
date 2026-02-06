#!/usr/bin/env ruby
require 'json'
require 'csv'

puts "=" * 60
puts "DEBUG SPECIAL REQUESTS"
puts "=" * 60

# Load state
state = JSON.parse(File.read('bridge_state.json'))
puts "\n✓ Loaded state"
puts "  Special requests in state: #{state['special_requests']&.size || 0}"
puts "  Match batches: #{state['match_batches']&.size || 0}"

# Get checked in people
checked_in = state['participants'].select { |_, p| p['checked_in'] }.values
puts "  Checked in: #{checked_in.size}"

# Helper to find by phone
def find_by_phone(phone, checked_in)
  phone_normalized = phone.to_s.gsub(/[^0-9]/, '')
  checked_in.find { |p| p['phone'].gsub(/[^0-9]/, '') == phone_normalized }
end

puts "\n" + "=" * 60
puts "SPECIAL REQUEST STATUS"
puts "=" * 60

workable = 0
not_workable = 0

state['special_requests'].each_with_index do |request, i|
  puts "\n##{i+1}: #{request['requester_name']} → #{request['requested_name']}"
  puts "  batches_together: #{request['batches_together']}"
  puts "  matched: #{request['matched']}"

  requester = find_by_phone(request['requester_phone'], checked_in)
  requested = request['requested_phone'] ? find_by_phone(request['requested_phone'], checked_in) : nil

  if requester
    puts "  ✓ Requester found: #{requester['name']} (checked_in: #{requester['checked_in']})"
  else
    puts "  ✗ Requester NOT found (phone: #{request['requester_phone']})"
  end

  if request['requested_phone']
    if requested
      puts "  ✓ Requested found: #{requested['name']} (checked_in: #{requested['checked_in']})"
    else
      puts "  ✗ Requested NOT found (phone: #{request['requested_phone']})"
    end
  else
    puts "  ⚠️  Requested phone is NULL - can't match by phone"
  end

  # Check if both are found and checked in
  if requester && requested && requester['checked_in'] && requested['checked_in']
    puts "  ✓✓ BOTH FOUND AND CHECKED IN"
    preview_batches = request['batches_together'] + 1
    puts "  Next batch would be: #{preview_batches}/2"
    if preview_batches == 2
      puts "  🎯 SHOULD MATCH ON NEXT BATCH!"
    end
    workable += 1
  else
    puts "  ✗✗ NOT WORKABLE (missing or not checked in)"
    not_workable += 1
  end
end

puts "\n" + "=" * 60
puts "SUMMARY"
puts "=" * 60
puts "Workable (both found & checked in): #{workable}"
puts "Not workable: #{not_workable}"

if workable == 0
  puts "\n⚠️  NO SPECIAL REQUESTS CAN MATCH!"
  puts "\nPossible reasons:"
  puts "1. Requested people have null phone numbers (can't be found)"
  puts "2. People aren't actually checked in"
  puts "3. Phone numbers don't match between state and special_requests.json"
  puts "\nTo fix: Need to add name-based matching fallback"
end

puts "\n" + "=" * 60
