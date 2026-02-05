#!/usr/bin/env ruby
require 'csv'

# Read waitlist data
waitlist = {}
CSV.foreach('waitlist_duplicate_rows.csv', headers: true) do |row|
  name = row['name']&.strip&.downcase
  next unless name

  waitlist[name] = {
    'email' => row['email'],
    'phone' => row['phone']
  }
end

puts "Loaded #{waitlist.size} entries from waitlist"
puts "Waitlist entries:"
waitlist.each { |name, data| puts "  #{name}: #{data['email']}, #{data['phone']}" }
puts

# Read and merge typeform data
typeform_rows = []
CSV.foreach('typeformbridgepub.csv', headers: true) do |row|
  typeform_rows << row
end

puts "Loaded #{typeform_rows.size} entries from typeform"

# Track duplicates by email
seen_emails = {}
duplicates_removed = 0

# Process in reverse to keep most recent (rows at end are newer)
merged_rows = []
typeform_rows.reverse.each do |row|
  name = row['What is your name?']&.strip
  email = row['What is your student email?']&.strip
  phone = row['What is your phone number?']&.strip

  next if name.nil? || name.empty?

  # Skip if we've already seen this email (keeping the more recent one)
  if email && !email.empty?
    if seen_emails[email.downcase]
      duplicates_removed += 1
      puts "Removing duplicate for #{email} (keeping most recent)"
      next
    end
    seen_emails[email.downcase] = true
  end

  # Check waitlist for missing data
  name_lower = name.downcase
  if waitlist[name_lower]
    if email.nil? || email.empty?
      row['What is your student email?'] = waitlist[name_lower]['email']
      puts "Filled email for #{name}: #{waitlist[name_lower]['email']}"
    end
    if phone.nil? || phone.empty?
      row['What is your phone number?'] = waitlist[name_lower]['phone']
      puts "Filled phone for #{name}: #{waitlist[name_lower]['phone']}"
    end
  end

  merged_rows << row
end

# Reverse back to original order
merged_rows.reverse!

puts
puts "Removed #{duplicates_removed} duplicate entries"
puts "Final count: #{merged_rows.size} entries"

# Write merged data
CSV.open('merged_participants.csv', 'w') do |csv|
  # Write headers
  csv << typeform_rows.first.headers

  # Write rows
  merged_rows.each do |row|
    csv << row
  end
end

puts
puts "=" * 50
puts "Merged data written to merged_participants.csv"
puts "=" * 50

# Show summary of missing data
missing_phone = merged_rows.count { |r| r['What is your phone number?'].to_s.strip.empty? }
missing_email = merged_rows.count { |r| r['What is your student email?'].to_s.strip.empty? }
missing_grade = merged_rows.count { |r| r['What grade are you in?'].to_s.strip.empty? }

puts
puts "Data quality summary:"
puts "  Total participants: #{merged_rows.size}"
puts "  Missing phone: #{missing_phone}"
puts "  Missing email: #{missing_email}"
puts "  Missing grade: #{missing_grade}"
puts
puts "Ready to use with bridge_matcher.rb"
puts "If running during event, use Menu Option 9 to reload data"
