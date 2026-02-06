#!/usr/bin/env ruby
require 'csv'

issues = []

CSV.foreach('/Users/saulbrauns/bridge-pub/current_bridge_pub_complete.csv', headers: true).with_index do |row, i|
  name = row['What is your name?']&.strip
  phone = row['What is your phone number?']&.strip
  gender = row['What is your gender?']&.strip
  male = row['Male']
  female = row['Female']
  nb = row['Non-binary']

  issues << "Row #{i+1} (#{name}): NO PHONE" if phone.nil? || phone.empty?
  issues << "Row #{i+1} (#{name}): NO GENDER" if gender.nil? || gender.empty?

  has_prefs = (male == 'Male') || (female == 'Female') || (nb == 'Non-binary')
  issues << "Row #{i+1} (#{name}): NO GENDER PREFS" unless has_prefs

  if phone && phone.length < 10
    issues << "Row #{i+1} (#{name}): SHORT PHONE (#{phone.length} digits: #{phone})"
  end
end

puts "CRITICAL DATA ISSUES: #{issues.size}"
issues.first(20).each { |i| puts "  - #{i}" }
puts "  ... and #{issues.size - 20} more" if issues.size > 20
