#!/usr/bin/env ruby
require 'csv'
require 'set'

# Normalize phone number to exactly 10 digits (consistent with bridge_matcher.rb)
# Handles country codes by taking last 10 digits
def normalize_phone(phone)
  return '' if phone.nil? || phone.empty?
  digits = phone.to_s.gsub(/[^0-9]/, '')
  # Always take last 10 digits to handle country codes like +1 or 1
  digits.length >= 10 ? digits[-10..-1] : digits
end

MAIN_CSV = 'merged_participants.csv'
WALKIN_CSV = 'walkin_test.csv'
OUTPUT_CSV = 'merged_participants.csv'

puts "=" * 60
puts "MERGING WALK-INS INTO MAIN PARTICIPANT LIST"
puts "=" * 60

# Load main participants
main_participants = []
main_emails = Set.new
main_phones = Set.new

puts "\nLoading #{MAIN_CSV}..."
CSV.foreach(MAIN_CSV, headers: true) do |row|
  main_participants << row
  email = row['What is your student email?']&.strip&.downcase
  phone = normalize_phone(row['What is your phone number?'])

  main_emails.add(email) if email && !email.empty?
  main_phones.add(phone) if phone && !phone.empty?
end

puts "✓ Loaded #{main_participants.size} existing participants"

# Load walk-ins
walk_ins = []
duplicates = []
new_count = 0

puts "\nLoading #{WALKIN_CSV}..."
CSV.foreach(WALKIN_CSV, headers: true) do |row|
  name = row['What is your full name?']&.strip
  email = row['What is your email address?']&.strip
  phone = row['What is your phone number?']&.strip

  next if name.nil? || name.empty?
  next if phone.nil? || phone.empty?

  # Normalize for duplicate check
  email_normalized = email&.downcase || ''
  phone_normalized = normalize_phone(phone)

  # Check for duplicates
  if main_emails.include?(email_normalized)
    duplicates << "#{name} (#{email}) - email already exists"
    next
  end

  if main_phones.include?(phone_normalized)
    duplicates << "#{name} (#{phone}) - phone already exists"
    next
  end

  # Map walk-in data to main CSV format
  grade = row['What year are you in college?']&.strip
  gender = row['What is your gender?']&.strip
  gender_prefs = row['Which gender(s) are you interested in?']&.strip || ''

  # Parse gender preferences (comma-separated in walk-in form)
  male_pref = gender_prefs.include?('Male') ? 'Male' : ''
  female_pref = gender_prefs.include?('Female') ? 'Female' : ''
  nb_pref = gender_prefs.include?('Non-binary') ? 'Non-binary' : ''

  # Generate unique ID
  unique_id = "walkin_#{Time.now.to_i}_#{rand(1000)}"

  # Create row matching main CSV structure
  new_row = [
    unique_id,                                    # ID
    name,                                         # What is your name?
    email,                                        # What is your student email?
    phone_normalized,                             # What is your phone number?
    '',                                           # Who do you want to see (empty)
    grade,                                        # What grade are you in?
    gender,                                       # What is your gender?
    male_pref,                                    # Male checkbox
    female_pref,                                  # Female checkbox
    nb_pref,                                      # Non-binary checkbox
    'Unknown',                                    # Academic school
    'Unknown',                                    # Ideal Friday
    'Unknown',                                    # Decision guide
    'Unknown',                                    # Plan vs spontaneous
    'Unknown',                                    # Fitness importance
    'Unknown',                                    # Important value
    'Unknown',                                    # Do you read
    'completed',                                  # Response type
    row['Submit Date (UTC)'] || Time.now.utc.to_s, # Start date
    '',                                           # Stage date
    row['Submit Date (UTC)'] || Time.now.utc.to_s, # Submit date
    'walkin',                                     # Network ID
    '',                                           # Tags
    'Walk-in registration'                        # Ending
  ]

  walk_ins << new_row
  new_count += 1

  puts "  ✓ #{name} (#{email})"
end

puts "\n#{new_count} new walk-ins to add"
puts "#{duplicates.size} duplicates skipped" if duplicates.size > 0

if duplicates.size > 0
  puts "\nDuplicates:"
  duplicates.each { |d| puts "  ✗ #{d}" }
end

# Write merged CSV
if new_count > 0
  puts "\nWriting to #{OUTPUT_CSV}..."

  CSV.open(OUTPUT_CSV, 'w') do |csv|
    # Write header
    csv << main_participants.first.headers

    # Write existing participants
    main_participants.each do |row|
      csv << row.fields
    end

    # Write new walk-ins
    walk_ins.each do |row|
      csv << row
    end
  end

  puts "✓ Merged successfully!"
  puts "\nTotal participants: #{main_participants.size + new_count}"
  puts "  Previous: #{main_participants.size}"
  puts "  Added: #{new_count}"
  puts "\n✓ Ready to reload in bridge_matcher.rb (Option 8)"
else
  puts "\nNo new walk-ins to add."
end

puts "=" * 60
