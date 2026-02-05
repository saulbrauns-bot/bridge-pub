#!/usr/bin/env ruby
require_relative 'bridge_matcher'

puts "\n" + "=" * 60
puts "CHECKING IN ALL PARTICIPANTS"
puts "=" * 60

# Load the system
load_participants
load_state
merge_state_with_participants

puts "\nTotal participants to check in: #{$participants.size}"

checked_in = 0
$state['participants'].each do |key, participant|
  next if participant['checked_in']  # Skip if already checked in

  wristband = $state['next_wristband_number']
  participant['checked_in'] = true
  participant['wristband_number'] = wristband
  $state['next_wristband_number'] += 1
  checked_in += 1

  print "." if checked_in % 10 == 0  # Progress indicator every 10 people
end

$state['last_operation'] = 'bulk_check_in'
save_state

puts "\n\n" + "=" * 60
puts "✓ CHECKED IN #{checked_in} PARTICIPANTS"
puts "=" * 60
puts "\nWristband numbers: #1 to ##{$state['next_wristband_number'] - 1}"
puts "State saved to: #{STATE_FILE}"
puts "\nRun 'ruby bridge_matcher.rb' to view status or generate matches"
