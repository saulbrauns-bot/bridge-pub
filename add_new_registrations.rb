#!/usr/bin/env ruby
require 'csv'
require 'set'

CURRENT_CSV = 'current_bridge_pub_complete.csv'

# Normalize phone number to exactly 10 digits (consistent with bridge_matcher.rb)
# Handles country codes by taking last 10 digits
def normalize_phone(phone)
  return '' if phone.nil? || phone.empty?
  digits = phone.to_s.gsub(/[^0-9]/, '')
  # Always take last 10 digits to handle country codes like +1 or 1
  digits.length >= 10 ? digits[-10..-1] : digits
end

puts "=" * 60
puts "ADD NEW REGISTRATIONS"
puts "=" * 60

# Get new CSV filename
print "\nEnter the name of the new CSV file: "
new_csv = gets.chomp.strip

unless File.exist?(new_csv)
  puts "\n✗ File not found: #{new_csv}"
  exit 1
end

# Load existing participants
existing_emails = Set.new
existing_phones = Set.new
existing_rows = []

puts "\nLoading current participants from #{CURRENT_CSV}..."
CSV.foreach(CURRENT_CSV, headers: true) do |row|
  existing_rows << row

  email = row['What is your student email?']&.strip&.downcase
  phone = normalize_phone(row['What is your phone number?'])

  existing_emails.add(email) if email && !email.empty?
  existing_phones.add(phone) if phone && !phone.empty?
end

puts "✓ Loaded #{existing_rows.size} existing participants"

# Load new registrations
new_rows = []
duplicates = []
added = 0

puts "\nLoading new registrations from #{new_csv}..."
CSV.foreach(new_csv, headers: true) do |row|
  name = row['What is your name?']&.strip
  email = row['What is your student email?']&.strip
  phone = row['What is your phone number?']&.strip

  next if name.nil? || name.empty?

  # Normalize for duplicate check
  email_normalized = email&.downcase || ''
  phone_final = normalize_phone(phone)

  # Skip if no phone (can't send SMS)
  if phone_final.empty?
    puts "  ⚠️  Skipped #{name} (no phone number)"
    next
  end

  # Skip if phone is not 10 digits after normalization
  if phone_final.length != 10
    puts "  ⚠️  Skipped #{name} (invalid phone: #{phone} → #{phone_final.length} digits)"
    next
  end

  # Check for duplicates
  if existing_emails.include?(email_normalized) || existing_phones.include?(phone_final)
    duplicates << "#{name} (#{email || phone})"
    next
  end

  # Store standardized 10-digit phone
  row['What is your phone number?'] = phone_final

  new_rows << row
  existing_emails.add(email_normalized)
  existing_phones.add(phone_final)
  added += 1

  puts "  ✓ #{name} (phone: #{phone_final})"
end

puts "\n#{added} new registrations to add"
puts "#{duplicates.size} duplicates skipped" if duplicates.any?

if duplicates.any?
  puts "\nDuplicates:"
  duplicates.each { |d| puts "  - #{d}" }
end

if added == 0
  puts "\n✗ No new registrations to add"
  exit 0
end

# Write merged CSV
puts "\nWriting updated #{CURRENT_CSV}..."
CSV.open(CURRENT_CSV, 'w') do |csv|
  # Write header
  csv << existing_rows.first.headers

  # Write existing participants
  existing_rows.each { |row| csv << row.fields }

  # Write new participants
  new_rows.each { |row| csv << row.fields }
end

puts "✓ Merged successfully!"
puts "\nTotal participants: #{existing_rows.size + added}"
puts "  Previous: #{existing_rows.size}"
puts "  Added: #{added}"

puts "\n✓ Ready to reload in bridge_matcher.rb (Option 8)"
puts "=" * 60
