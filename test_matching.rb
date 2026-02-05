#!/usr/bin/env ruby
require 'set'
require_relative 'bridge_matcher'

puts "\n" + "=" * 60
puts "TEST RUN - Checking in 10 participants"
puts "=" * 60

# Load the system
load_participants
load_state
merge_state_with_participants

# Check in 10 people manually
test_people = [
  'Js306@rice.edu',      # Joe Slipper (Male, likes Female)
  'Je58@rice.edu',       # Jeswill (Male, likes Female)
  'ok18@rice.edu',       # Oliwia (Female, likes Male)
  'aj110@rice.edu',      # amaya j (Female, likes Male/Female)
  'bv23@rice.edu',       # Banesa (Female, likes Male)
  'Kc215@rice.edu',      # Katie (Female, likes Male)
  'lw125@rice.edu',      # Lilly (Female, likes Male)
  'sz122@rice.edu',      # Steve Zhang (Male, likes Female)
  'eq6@rice.edu',        # Emma Qian (Female, likes Male)
  'cz103@rice.edu'       # claire (Female, likes Male/Female)
]

checked_in = 0
test_people.each do |email|
  participant = $state['participants'][email]
  if participant
    wristband = $state['next_wristband_number']
    participant['checked_in'] = true
    participant['wristband_number'] = wristband
    $state['next_wristband_number'] += 1
    checked_in += 1
    puts "✓ Checked in: #{participant['name']} - Wristband ##{wristband}"
  end
end

save_state
puts "\n✓ Checked in #{checked_in} participants"

# Show status
puts "\n" + "=" * 60
puts "CHECKED IN PARTICIPANTS"
puts "=" * 60
get_checked_in_participants.values.sort_by { |p| p['wristband_number'] }.each do |p|
  puts "##{p['wristband_number']} - #{p['name']} (#{p['gender']}, likes #{p['gender_preferences'].join('/')})"
  puts "  Grade: #{p['grade'] || 'Not specified'}"
  puts "  Fitness: #{p['fitness_importance']}"
  puts "  Value: #{p['important_value']}"
  puts
end

# Generate matches
puts "=" * 60
puts "GENERATING MATCHES"
puts "=" * 60

checked_in_list = get_checked_in_participants.values

# Build compatibility matrix
puts "\nCalculating compatibility scores..."
romantic_pairs = []

checked_in_list.each_with_index do |p1, i|
  checked_in_list[i+1..-1].each do |p2|
    next unless can_match?(p1, p2, romantic: true)

    score = calculate_compatibility_score(p1, p2)
    romantic_pairs << {
      'p1' => p1,
      'p2' => p2,
      'score' => score
    }
  end
end

puts "Found #{romantic_pairs.size} compatible romantic pairs"

# Show all compatible pairs with scores
puts "\n" + "=" * 60
puts "ALL COMPATIBLE PAIRS (sorted by score)"
puts "=" * 60
romantic_pairs.sort_by { |pair| -pair['score'] }.each do |pair|
  p1 = pair['p1']
  p2 = pair['p2']
  puts "#{p1['name']} (##{p1['wristband_number']}) ↔ #{p2['name']} (##{p2['wristband_number']})"
  puts "  Score: #{pair['score']}/130"
  puts "  Grade match: #{p1['grade']} + #{p2['grade']}"
  puts "  Fitness match: #{p1['fitness_importance']} + #{p2['fitness_importance']}"
  puts "  Value match: #{p1['important_value']} + #{p2['important_value']}"
  puts
end

# Maximum weighted matching
puts "=" * 60
puts "OPTIMAL MATCHES (greedy algorithm)"
puts "=" * 60

romantic_pairs.sort_by! { |pair| -pair['score'] }

matched = Set.new
romantic_matches = []

romantic_pairs.each do |pair|
  p1_key = pair['p1']['key']
  p2_key = pair['p2']['key']

  next if matched.include?(p1_key) || matched.include?(p2_key)

  romantic_matches << pair
  matched << p1_key
  matched << p2_key
end

puts "\n✓ Generated #{romantic_matches.size} romantic matches"
puts

romantic_matches.each_with_index do |pair, i|
  p1 = pair['p1']
  p2 = pair['p2']
  puts "Match #{i+1}:"
  puts "  #{p1['name']} (##{p1['wristband_number']}) ↔ #{p2['name']} (##{p2['wristband_number']})"
  puts "  Compatibility Score: #{pair['score']}/130"
  puts "  Message to #{p1['name']}: \"Your Bridge match is #{p2['name']}, sign in ##{p2['wristband_number']}!\""
  puts "  Message to #{p2['name']}: \"Your Bridge match is #{p1['name']}, sign in ##{p1['wristband_number']}!\""
  puts
end

# Show unmatched
unmatched = checked_in_list.reject { |p| matched.include?(p['key']) }
if unmatched.any?
  puts "⚠ Unmatched (#{unmatched.size}):"
  unmatched.each do |p|
    puts "  #{p['name']} (##{p['wristband_number']})"
  end
  puts "\n(Would get friend matches in real run)"
end

puts "\n" + "=" * 60
puts "TEST COMPLETE - State NOT saved"
puts "=" * 60
