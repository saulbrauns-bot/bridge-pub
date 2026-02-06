#!/usr/bin/env ruby
require 'csv'
require 'json'

# Normalize phone number to exactly 10 digits (consistent with bridge_matcher.rb)
# Handles country codes by taking last 10 digits
def normalize_phone(phone)
  return '' if phone.nil? || phone.empty?
  digits = phone.to_s.gsub(/[^0-9]/, '')
  # Always take last 10 digits to handle country codes like +1 or 1
  digits.length >= 10 ? digits[-10..-1] : digits
end

puts "=" * 60
puts "SPECIAL REQUEST VALIDATION"
puts "=" * 60

# Load participants
participants = []
CSV.foreach('current_bridge_pub_complete.csv', headers: true) do |row|
  phone = normalize_phone(row['What is your phone number?'])
  name = row['What is your name?']&.strip

  next if phone.nil? || phone.empty?

  participants << {
    'name' => name,
    'phone' => phone,
    'name_lower' => name&.downcase&.strip
  }
end

puts "\n✓ Loaded #{participants.size} participants from CSV"

# Load special requests
special_requests = JSON.parse(File.read('special_requests.json'))
puts "✓ Loaded #{special_requests.size} special requests"

# Validate each request
valid_requests = []
invalid_requests = []

puts "\n" + "=" * 60
puts "VALIDATION RESULTS"
puts "=" * 60

special_requests.each_with_index do |request, i|
  requester_phone = request['requester_phone']
  requested_phone = request['requested_phone']
  requester_name = request['requester_name']
  requested_name = request['requested_name']

  # Find requester
  requester_phone_normalized = normalize_phone(requester_phone)
  requester = participants.find { |p| p['phone'] == requester_phone_normalized }

  # Find requested person (by phone if available, otherwise by EXACT name)
  requested = nil
  if requested_phone
    requested_phone_normalized = normalize_phone(requested_phone)
    requested = participants.find { |p| p['phone'] == requested_phone_normalized }
  end

  # Try EXACT name matching if phone didn't work (matching bridge_matcher.rb logic)
  if requested.nil? && requested_name
    requested_name_lower = requested_name.downcase.strip
    # EXACT match only - no fuzzy substring matching
    requested = participants.find { |p| p['name_lower'] == requested_name_lower }
  end

  # Categorize
  if requester && requested
    valid_requests << request
    puts "\n✓ VALID ##{i+1}: #{requester_name} → #{requested_name}"
    puts "  Requester: #{requester['name']} (#{requester_phone})"
    puts "  Requested: #{requested['name']} (#{requested['phone']})"
  else
    invalid_requests << {
      'request' => request,
      'requester_found' => !requester.nil?,
      'requested_found' => !requested.nil?
    }

    puts "\n✗ INVALID ##{i+1}: #{requester_name} → #{requested_name}"
    if !requester
      puts "  ⚠️  Requester NOT FOUND: #{requester_name} (#{requester_phone})"
    else
      puts "  ✓ Requester: #{requester['name']} (#{requester_phone})"
    end

    if !requested
      puts "  ⚠️  Requested NOT FOUND: #{requested_name}"
      if requested_phone
        puts "     Phone: #{requested_phone}"
      else
        puts "     Phone: (not provided - likely walk-in)"
      end
    else
      puts "  ✓ Requested: #{requested['name']}"
    end
  end
end

# Summary
puts "\n" + "=" * 60
puts "SUMMARY"
puts "=" * 60
puts "\nTotal special requests: #{special_requests.size}"
puts "✓ Valid (both people exist): #{valid_requests.size}"
puts "✗ Invalid (one or both missing): #{invalid_requests.size}"

if invalid_requests.any?
  puts "\nBreakdown of invalid requests:"
  requester_missing = invalid_requests.count { |r| !r['requester_found'] }
  requested_missing = invalid_requests.count { |r| !r['requested_found'] }
  puts "  Requester missing: #{requester_missing}"
  puts "  Requested person missing: #{requested_missing}"

  puts "\nMost likely explanation:"
  puts "  - Requested people haven't registered yet"
  puts "  - They may show up as walk-ins during the event"
  puts "  - When walk-ins register with matching phone numbers,"
  puts "    special requests will automatically become valid"
end

puts "\n" + "=" * 60
