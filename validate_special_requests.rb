#!/usr/bin/env ruby
require 'csv'
require 'json'

puts "=" * 60
puts "SPECIAL REQUEST VALIDATION"
puts "=" * 60

# Load participants
participants = []
CSV.foreach('current_bridge_pub_complete.csv', headers: true) do |row|
  phone = row['What is your phone number?']&.strip&.gsub(/[^0-9]/, '')
  name = row['What is your name?']&.strip

  next if phone.nil? || phone.empty?

  participants << {
    'name' => name,
    'phone' => phone,
    'name_lower' => name&.downcase
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
  requester = participants.find { |p| p['phone'] == requester_phone }

  # Find requested person (by phone if available, otherwise by name)
  requested = nil
  if requested_phone
    requested = participants.find { |p| p['phone'] == requested_phone }
  end

  # Try name matching if phone didn't work
  if requested.nil? && requested_name
    requested_name_lower = requested_name.downcase
    requested = participants.find do |p|
      p['name_lower']&.include?(requested_name_lower) ||
      requested_name_lower.include?(p['name_lower'] || '')
    end
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
