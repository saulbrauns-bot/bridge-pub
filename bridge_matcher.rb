#!/usr/bin/env ruby
require 'csv'
require 'json'
require 'time'
require 'set'
require_relative 'generate_matches_page'

# Load environment variables from .env file
if File.exist?('.env')
  File.readlines('.env').each do |line|
    next if line.strip.empty? || line.start_with?('#')
    key, value = line.strip.split('=', 2)
    ENV[key] = value
  end
end

# Constants
MERGED_CSV = 'current_bridge_pub_complete.csv'
STATE_FILE = 'bridge_state.json'
EXPORT_FILE = 'bridge_matches_export.csv'

# Free entry list (don't owe $3)
FREE_ENTRY_EMAILS = [
  'ayp2@rice.edu',           # Aanika Porras
  'ak285@rice.edu',          # Arben
  'Bd63@rice.edu',           # Bianca Dotson
  'bh80@rice.edu',           # Boyan Holt
  'dc118@rice.edu',          # Demetris Chrysostomou
  'hw106@rice.edu',          # Harrison White
  'hl203@rice.edu',          # Hayden Lucas
  'hc103@rice.edu',          # Hemesh Chadalavada
  'Il36@rice.edu',           # Izzy Leyton
  'Lk70@rice.edu',           # Logan Koplovitz
  'Mjr16@rice.edu',          # Matthew Ramos
  'ma233@rice.edu',          # Mehmet Acikel
  'rw73@rice.edu',           # Ruiyang Wu
  'sj163@rice.edu',          # Shyla
  'qat1@rice.edu',           # Quincy Tate
  'Cc321@rice.edu',          # Coffey Collier
  'ey27@rice.edu',           # Emma Young
  'km108@rice.edu',          # Kenny Manning
  'er106@rice.edu',          # Evelyn Rodriguez
  'lw125@rice.edu',          # Lilly Wu
  'mn108@rice.edu',          # Muneeb Nazir
  'rohanamin0807@gmail.com', # Rohan Amin
  'me83@rice.edu',           # Hassan
  'At253@rice.edu',          # Adam
  'rc183@rice.edu',          # Ria Chauhan
  'cs282@rice.edu'           # Carter Sakai
].map(&:downcase)

GRADES = {
  'Freshman' => 1,
  'Sophomore' => 2,
  'Junior' => 3,
  'Senior' => 4
}

FITNESS_LEVELS = {
  'Extremely important' => 4,
  'Somewhat important' => 3,
  'Neutral' => 2,
  'Not very important' => 1
}

# Global state
$participants = {}
$state = {
  'match_batches' => [],
  'participants' => {},
  'next_wristband_number' => 1,
  'next_walkin_wristband_number' => 250,
  'special_requests' => [],
  'last_operation' => nil,
  'last_updated' => nil
}

# ============================================================================
# DATA LOADING
# ============================================================================

def load_participants
  puts "\nLoading participants from #{MERGED_CSV}..."

  count = 0
  skipped = 0

  CSV.foreach(MERGED_CSV, headers: true) do |row|
    name = row['What is your name?']&.strip
    email = row['What is your student email?']&.strip
    phone = row['What is your phone number?']&.strip

    # Skip if no name
    next if name.nil? || name.empty?

    # Skip if no phone (can't send SMS)
    if phone.nil? || phone.empty?
      skipped += 1
      next
    end

    # Use email as key, fallback to name if no email
    key = email && !email.empty? ? email : name.downcase.gsub(/\s+/, '_')

    # Parse gender preferences (columns 7, 8, 9 are Male, Female, Non-binary checkboxes)
    gender_prefs = []
    gender_prefs << 'Male' if row['Male'] == 'Male'
    gender_prefs << 'Female' if row['Female'] == 'Female'
    gender_prefs << 'Non-binary' if row['Non-binary'] == 'Non-binary'

    $participants[key] = {
      'key' => key,
      'name' => name,
      'email' => email || '',
      'phone' => phone,
      'grade' => row['What grade are you in?']&.strip,
      'gender' => row['What is your gender?']&.strip,
      'gender_preferences' => gender_prefs,
      'school' => row['What academic school do you study at?']&.strip,
      'ideal_friday' => row['Which of these is most like your ideal Friday night?']&.strip,
      'decision_guide' => row['What guides your decisions?']&.strip,
      'plan_spontaneous' => row['Do you prefer to plan or be spontaneous?']&.strip,
      'fitness_importance' => row['How important is fitness and nutrition to you?']&.strip,
      'important_value' => row['Which value is most important to you in a partner?']&.strip,
      'reading' => row['Do you read?']&.strip
    }

    count += 1
  end

  puts "✓ Loaded #{count} participants"
  puts "✗ Skipped #{skipped} participants (missing phone numbers)" if skipped > 0

  count
end

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

def load_state
  if File.exist?(STATE_FILE)
    puts "Loading previous state from #{STATE_FILE}..."
    $state = JSON.parse(File.read(STATE_FILE))

    # Ensure new fields exist (for backwards compatibility)
    $state['next_walkin_wristband_number'] ||= 250
    $state['special_requests'] ||= []

    puts "✓ State loaded (#{$state['participants'].size} participants in state)"
  else
    puts "No previous state found, starting fresh"
  end
end

def load_special_requests
  if File.exist?('special_requests.json')
    puts "Loading special requests..."
    requests = JSON.parse(File.read('special_requests.json'))

    # Merge with existing state (preserve batches_together counter)
    requests.each do |request|
      existing = $state['special_requests'].find do |r|
        r['requester_phone'] == request['requester_phone'] &&
        r['requested_phone'] == request['requested_phone']
      end

      if existing
        # Update names but keep counters
        existing['requester_name'] = request['requester_name']
        existing['requested_name'] = request['requested_name']
        existing['requested_phone'] = request['requested_phone'] if request['requested_phone']
      else
        # Add new request
        $state['special_requests'] << request
      end
    end

    save_state
    puts "✓ Loaded #{$state['special_requests'].size} special requests"
  else
    puts "No special_requests.json found (skip special matching)"
  end
end

def save_state
  $state['last_updated'] = Time.now.utc.iso8601
  File.write(STATE_FILE, JSON.pretty_generate($state))
end

def merge_state_with_participants
  puts "Merging CSV data with state..."
  puts "  CSV has #{$participants.size} participants"
  puts "  State has #{$state['participants'].size} participants"

  # Merge loaded participants with existing state
  $participants.each do |key, participant|
    if $state['participants'][key]
      # Participant exists in state, update their data but keep state info
      $state['participants'][key].merge!(participant)
    else
      # New participant, initialize state
      # Check if they're on the free entry list
      is_free = FREE_ENTRY_EMAILS.include?(key.downcase)

      $state['participants'][key] = participant.merge({
        'checked_in' => false,
        'wristband_number' => nil,
        'matched_with_emails' => [],
        'payment_required' => !is_free
      })
    end

    # Update payment_required based on free entry list (for existing participants)
    is_free = FREE_ENTRY_EMAILS.include?(key.downcase)
    $state['participants'][key]['payment_required'] = !is_free
  end

  # Remove participants from state who are NOT in the loaded CSV
  removed_count = 0
  $state['participants'].keys.each do |key|
    unless $participants.key?(key)
      puts "  ✗ Removing #{key} from state (not in CSV)"
      $state['participants'].delete(key)
      removed_count += 1
    end
  end

  if removed_count > 0
    puts "  Removed #{removed_count} participants not in CSV"
  end
  puts "  Final state has #{$state['participants'].size} participants"

  save_state
end

def get_participant_state(key)
  $state['participants'][key]
end

def get_checked_in_participants
  $state['participants'].select { |k, p| p['checked_in'] }
end

# ============================================================================
# CLI MENU
# ============================================================================

def show_menu
  checked_in_count = get_checked_in_participants.size
  total_matches = $state['match_batches'].sum { |b| b['matches'].size }
  batches_sent = $state['match_batches'].count { |b| b['sent_at'] }

  # Count gender breakdown
  checked_in = get_checked_in_participants.values
  males = checked_in.count { |p| p['gender']&.downcase == 'male' }
  females = checked_in.count { |p| p['gender']&.downcase == 'female' }
  non_binary = checked_in.count { |p| p['gender']&.downcase == 'non-binary' }

  puts "\n" + "=" * 60
  puts "=== BRIDGE PUB MATCHER ==="
  puts "Batches sent: #{batches_sent} | Total matches: #{total_matches} | Checked in: #{checked_in_count}"
  puts "Gender: #{males}M / #{females}F / #{non_binary}NB"
  puts "=" * 60
  puts
  puts "1. Check in participant (pre-registered)"
  puts "2. Check out participant"
  puts "3. View current status"
  puts "4. Generate new matches"
  puts "5. Send matches via Twilio"
  puts "6. Export results"
  puts "7. Reset system (USE WITH CAUTION)"
  puts "8. Reload participant data (for new survey responses)"
  puts "9. Exit"
  puts "10. Check in EVERYONE (auto)"
  puts "11. Check in WALK-IN (wristband #250+)"
  puts "12. Undo last check-in/out"
  puts
  print "Choose option: "
end

def main_menu
  loop do
    show_menu
    choice = gets.chomp

    case choice
    when '1' then check_in_participant
    when '2' then check_out_participant
    when '3' then view_status
    when '4' then generate_matches
    when '5' then send_matches
    when '6' then export_results
    when '7' then reset_system
    when '8' then reload_data
    when '9'
      puts "\nGoodbye! State saved to #{STATE_FILE}"
      exit 0
    when '10' then check_in_everyone
    when '11' then check_in_walkin
    when '12' then undo_last_checkin
    else
      puts "\n✗ Invalid option. Please choose 1-12."
    end

    puts "\nPress Enter to continue..."
    gets
  end
end

# ============================================================================
# CHECK IN/OUT
# ============================================================================

def check_in_participant
  puts "\n=== CHECK IN PARTICIPANT ==="
  print "Enter name or email: "
  search = gets.chomp.strip.downcase

  # Find participant
  matches = $state['participants'].select do |key, p|
    p['name'].downcase.include?(search) ||
    p['email'].downcase.include?(search) ||
    key.downcase.include?(search)
  end

  if matches.empty?
    puts "\n✗ No participant found matching '#{search}'"
    return
  end

  if matches.size > 1
    puts "\nMultiple matches found:"
    matches.each_with_index do |(key, p), i|
      puts "#{i+1}. #{p['name']} (#{p['email']})"
    end
    print "\nChoose number (or 0 to cancel): "
    choice = gets.chomp.to_i

    if choice == 0 || choice > matches.size
      puts "Cancelled"
      return
    end

    key = matches.keys[choice - 1]
  else
    key = matches.keys.first
  end

  participant = $state['participants'][key]

  if participant['checked_in']
    puts "\n✓ #{participant['name']} is already checked in (Wristband ##{participant['wristband_number']})"
    return
  end

  # Assign wristband (or reuse if they had one before)
  if participant['wristband_number'].nil?
    wristband = $state['next_wristband_number']
    participant['wristband_number'] = wristband
    $state['next_wristband_number'] += 1
  else
    wristband = participant['wristband_number']
    puts "  (Reusing previous wristband)"
  end
  participant['checked_in'] = true

  $state['last_operation'] = 'check_in'
  $state['last_checked_in_key'] = key
  $state['last_checked_in_type'] = 'regular'
  save_state

  puts "\n✓ Checked in: #{participant['name']}"
  puts "  Wristband ##{wristband}"
  puts "  Phone: #{participant['phone']}"

  # Show payment status
  if participant['payment_required']
    puts "  💰 OWES $3"
  else
    puts "  ✓ FREE ENTRY"
  end
end

def check_in_walkin
  puts "\n=== CHECK IN WALK-IN (Wristband #250+) ==="
  print "Enter name or email: "
  search = gets.chomp.strip.downcase

  # Find participant
  matches = $state['participants'].select do |key, p|
    p['name'].downcase.include?(search) ||
    p['email'].downcase.include?(search) ||
    key.downcase.include?(search)
  end

  if matches.empty?
    puts "\n✗ No participant found matching '#{search}'"
    return
  end

  if matches.size > 1
    puts "\nMultiple matches found:"
    matches.each_with_index do |(key, p), i|
      puts "#{i+1}. #{p['name']} (#{p['email']})"
    end
    print "\nChoose number (or 0 to cancel): "
    choice = gets.chomp.to_i

    if choice == 0 || choice > matches.size
      puts "Cancelled"
      return
    end

    key = matches.keys[choice - 1]
  else
    key = matches.keys.first
  end

  participant = $state['participants'][key]

  if participant['checked_in']
    puts "\n✓ #{participant['name']} is already checked in (Wristband ##{participant['wristband_number']})"
    return
  end

  # Assign walk-in wristband (or reuse if they had one before)
  if participant['wristband_number'].nil?
    wristband = $state['next_walkin_wristband_number']
    participant['wristband_number'] = wristband
    $state['next_walkin_wristband_number'] += 1
  else
    wristband = participant['wristband_number']
    puts "  (Reusing previous wristband)"
  end
  participant['checked_in'] = true

  $state['last_operation'] = 'check_in_walkin'
  $state['last_checked_in_key'] = key
  $state['last_checked_in_type'] = 'walkin'
  save_state

  puts "\n✓ Checked in WALK-IN: #{participant['name']}"
  puts "  Wristband ##{wristband} (WALK-IN)"
  puts "  Phone: #{participant['phone']}"

  # Show payment status
  if participant['payment_required']
    puts "  💰 OWES $3"
  else
    puts "  ✓ FREE ENTRY"
  end
end

def check_out_participant
  puts "\n=== CHECK OUT PARTICIPANT ==="
  print "Enter name, email, or wristband number: "
  search = gets.chomp.strip

  # Find participant
  # If search is a number, only search by wristband (exact match)
  # Otherwise search by name/email/key (substring match)
  if search.match?(/^\d+$/)
    # Pure number - only match wristband exactly
    matches = $state['participants'].select do |key, p|
      p['checked_in'] && p['wristband_number'].to_s == search
    end
  else
    # Text search - match name/email/key
    search_lower = search.downcase
    matches = $state['participants'].select do |key, p|
      p['checked_in'] && (
        p['name'].downcase.include?(search_lower) ||
        p['email'].downcase.include?(search_lower) ||
        key.downcase.include?(search_lower)
      )
    end
  end

  if matches.empty?
    puts "\n✗ No checked-in participant found matching '#{search}'"
    return
  end

  if matches.size > 1
    puts "\nMultiple matches found:"
    matches.each_with_index do |(key, p), i|
      puts "#{i+1}. #{p['name']} - Wristband ##{p['wristband_number']}"
    end
    print "\nChoose number (or 0 to cancel): "
    choice = gets.chomp.to_i

    if choice == 0 || choice > matches.size
      puts "Cancelled"
      return
    end

    key = matches.keys[choice - 1]
  else
    key = matches.keys.first
  end

  participant = $state['participants'][key]
  participant['checked_in'] = false

  $state['last_operation'] = 'check_out'
  $state['last_checked_out_key'] = key
  save_state

  puts "\n✓ Checked out: #{participant['name']} (Wristband ##{participant['wristband_number']})"
end

def check_in_everyone
  puts "\n=== CHECK IN EVERYONE ==="

  not_checked_in = $state['participants'].select { |k, p| !p['checked_in'] }

  if not_checked_in.empty?
    puts "\n✓ Everyone is already checked in!"
    return
  end

  puts "#{not_checked_in.size} people are not checked in yet"
  print "Check in all #{not_checked_in.size} people? (yes/no): "
  confirm = gets.chomp.downcase

  return unless confirm == 'yes' || confirm == 'y'

  checked_in_count = 0
  not_checked_in.each do |key, participant|
    wristband = $state['next_wristband_number']
    participant['checked_in'] = true
    participant['wristband_number'] = wristband
    $state['next_wristband_number'] += 1
    checked_in_count += 1

    print "." if checked_in_count % 10 == 0  # Progress dots
  end

  $state['last_operation'] = 'bulk_check_in'
  save_state

  puts "\n\n✓ Checked in #{checked_in_count} people"
  puts "  Wristband numbers: ##{$state['next_wristband_number'] - checked_in_count} to ##{$state['next_wristband_number'] - 1}"
end

def undo_last_checkin
  puts "\n=== UNDO LAST OPERATION ==="

  last_op = $state['last_operation']

  unless last_op == 'check_in' || last_op == 'check_in_walkin' || last_op == 'check_out'
    puts "\n✗ No recent check-in/out to undo"
    puts "  Last operation: #{last_op || 'none'}"
    return
  end

  # Determine which operation to undo
  if last_op == 'check_out'
    # Undo a check-out (re-check them in)
    key = $state['last_checked_out_key']

    unless key
      puts "\n✗ No check-out to undo"
      return
    end

    participant = $state['participants'][key]

    unless participant
      puts "\n✗ Cannot find participant"
      return
    end

    if participant['checked_in']
      puts "\n✗ #{participant['name']} is already checked in"
      return
    end

    # Show what will be undone
    puts "\nLast check-out:"
    puts "  Name: #{participant['name']}"
    puts "  Wristband: ##{participant['wristband_number']}"

    print "\nUndo this check-out (re-check them in)? (yes/no): "
    confirm = gets.chomp.downcase

    return unless confirm == 'yes' || confirm == 'y'

    # Re-check them in
    participant['checked_in'] = true

    # Clear tracking
    $state['last_checked_out_key'] = nil
    $state['last_operation'] = 'undo_checkout'

    save_state

    puts "\n✓ Undone! #{participant['name']} is checked back in"
    puts "  Wristband: ##{participant['wristband_number']}"

  else
    # Undo a check-in
    key = $state['last_checked_in_key']

    unless key
      puts "\n✗ No check-in to undo"
      return
    end

    participant = $state['participants'][key]

    unless participant
      puts "\n✗ Cannot find participant"
      return
    end

    unless participant['checked_in']
      puts "\n✗ #{participant['name']} is not checked in"
      return
    end

    # Show what will be undone
    puts "\nLast check-in:"
    puts "  Name: #{participant['name']}"
    puts "  Wristband: ##{participant['wristband_number']}"
    puts "  Type: #{$state['last_checked_in_type'] || 'regular'}"

    print "\nUndo this check-in? (yes/no): "
    confirm = gets.chomp.downcase

    return unless confirm == 'yes' || confirm == 'y'

    # Undo the check-in
    wristband_freed = participant['wristband_number']
    participant['checked_in'] = false
    participant['wristband_number'] = nil

    # Decrement the appropriate counter
    if $state['last_checked_in_type'] == 'walkin'
      $state['next_walkin_wristband_number'] -= 1
    else
      $state['next_wristband_number'] -= 1
    end

    # Clear tracking
    $state['last_checked_in_key'] = nil
    $state['last_checked_in_type'] = nil
    $state['last_operation'] = 'undo_checkin'

    save_state

    puts "\n✓ Undone! #{participant['name']} is no longer checked in"
    puts "  Wristband ##{wristband_freed} is now available again"
  end
end

# ============================================================================
# STATUS VIEW
# ============================================================================

def view_status
  puts "\n=== CURRENT STATUS ==="

  checked_in = get_checked_in_participants
  batches_sent = $state['match_batches'].count { |b| b['sent_at'] }
  total_matches = $state['match_batches'].sum { |b| b['matches'].size }

  # Gender balance
  males_in = checked_in.count { |k, p| p['gender'] == 'Male' }
  females_in = checked_in.count { |k, p| p['gender'] == 'Female' }
  nonbinary_in = checked_in.count { |k, p| p['gender'] == 'Non-binary' }

  # Count match distribution
  match_counts = Hash.new(0)
  never_matched = 0

  $state['participants'].each do |key, p|
    count = p['matched_with_emails'].size
    match_counts[count] += 1
    never_matched += 1 if count == 0 && p['checked_in']
  end

  puts "\nOverall:"
  puts "  Total participants: #{$state['participants'].size}"
  puts "  Checked in: #{checked_in.size}"
  puts "    Males: #{males_in}"
  puts "    Females: #{females_in}"
  puts "    Non-binary: #{nonbinary_in}"
  puts "  Batches sent: #{batches_sent}"
  puts "  Total matches made: #{total_matches}"
  puts "  People never matched (checked in): #{never_matched}"

  puts "\nMatch distribution:"
  match_counts.sort.each do |count, num_people|
    puts "  #{num_people} people with #{count} matches"
  end

  if checked_in.any?
    puts "\nChecked in participants:"
    checked_in.sort_by { |k, p| p['wristband_number'] }.each do |key, p|
      match_count = p['matched_with_emails'].size
      payment_status = if p['payment_required']
        " [OWES $3]"
      else
        " [FREE]"
      end
      puts "  ##{p['wristband_number']} - #{p['name']} (#{match_count} matches)#{payment_status}"
    end

    # Show payment summary
    owed_count = checked_in.count { |k, p| p['payment_required'] }
    free_count = checked_in.count { |k, p| !p['payment_required'] }
    total_owed = owed_count * 3

    puts "\n💰 Payment Summary:"
    puts "  Free entry: #{free_count}"
    puts "  Owe $3: #{owed_count}"
    puts "  Total to collect: $#{total_owed}"
  else
    puts "\nNo participants checked in yet"
  end

  # Show unsent batches
  unsent = $state['match_batches'].select { |b| !b['sent_at'] }
  if unsent.any?
    puts "\n⚠ WARNING: #{unsent.size} batch(es) generated but not sent yet!"
  end

  # Option to search for specific person
  puts "\n" + "-" * 60
  print "Search for specific person? (press Enter to skip, or type name): "
  search = gets.chomp.strip

  unless search.empty?
    matches = $state['participants'].select do |key, p|
      p['name'].downcase.include?(search.downcase) ||
      p['email'].downcase.include?(search.downcase) ||
      p['wristband_number'].to_s == search
    end

    if matches.empty?
      puts "✗ No one found matching '#{search}'"
    else
      matches.each do |key, p|
        puts "\n" + "=" * 60
        puts "#{p['name']} - Wristband ##{p['wristband_number'] || 'Not assigned'}"
        puts "=" * 60
        puts "Email: #{p['email']}"
        puts "Phone: #{p['phone']}"
        puts "Checked in: #{p['checked_in'] ? 'YES' : 'NO'}"
        puts "Gender: #{p['gender']} (likes #{p['gender_preferences'].join('/')})"
        puts "Grade: #{p['grade'] || 'Not specified'}"
        puts "Total matches: #{p['matched_with_emails'].size}"

        # Show payment status
        payment_status = p['payment_required'] ? "OWES $3" : "FREE ENTRY"
        puts "Payment: #{payment_status}"

        if p['matched_with_emails'].any?
          puts "\nMatched with:"
          p['matched_with_emails'].each do |match_key|
            matched_person = $state['participants'][match_key]
            if matched_person
              puts "  - #{matched_person['name']} (Wristband ##{matched_person['wristband_number']})"
            end
          end
        end
      end
    end
  end
end

# ============================================================================
# MATCHING ALGORITHM
# ============================================================================

def calculate_compatibility_score(p1, p2)
  score = 0

  # 1. Grade Proximity (0-20 points)
  if p1['grade'] && p2['grade'] && GRADES[p1['grade']] && GRADES[p2['grade']]
    grade_diff = (GRADES[p1['grade']] - GRADES[p2['grade']]).abs
    score += case grade_diff
    when 0 then 20  # Same grade
    when 1 then 10  # Adjacent
    when 2 then 5   # 2 apart
    else 0
    end
  end

  # 2. School Match (0-10 points)
  if p1['school'] && p2['school'] && p1['school'] == p2['school']
    score += 10
  end

  # 3. Ideal Friday Night (0-15 points)
  if p1['ideal_friday'] && p2['ideal_friday'] && p1['ideal_friday'] == p2['ideal_friday']
    score += 15
  end

  # 4. Decision Guide: Emotion vs Logic (0-15 points)
  if p1['decision_guide'] && p2['decision_guide'] && p1['decision_guide'] == p2['decision_guide']
    score += 15
  end

  # 5. Plan vs Spontaneous (0-15 points)
  if p1['plan_spontaneous'] && p2['plan_spontaneous'] && p1['plan_spontaneous'] == p2['plan_spontaneous']
    score += 15
  end

  # 6. Fitness Importance (0-20 points) - WEIGHTED HIGHER
  if p1['fitness_importance'] && p2['fitness_importance'] &&
     FITNESS_LEVELS[p1['fitness_importance']] && FITNESS_LEVELS[p2['fitness_importance']]
    fitness_diff = (FITNESS_LEVELS[p1['fitness_importance']] - FITNESS_LEVELS[p2['fitness_importance']]).abs
    score += case fitness_diff
    when 0 then 20  # Exact match
    when 1 then 10  # One level apart
    else 0
    end
  end

  # 7. Important Value (0-20 points)
  if p1['important_value'] && p2['important_value'] && p1['important_value'] == p2['important_value']
    score += 20
  end

  # 8. Reading Habit (0-10 points)
  if p1['reading'] && p2['reading'] && p1['reading'] == p2['reading']
    score += 10
  end

  score
end

def gender_compatible?(p1, p2)
  # Check if p1's gender is in p2's preferences and vice versa
  return false unless p1['gender'] && p2['gender']
  return false if p1['gender_preferences'].empty? || p2['gender_preferences'].empty?

  p1_in_p2 = p2['gender_preferences'].include?(p1['gender'])
  p2_in_p1 = p1['gender_preferences'].include?(p2['gender'])

  p1_in_p2 && p2_in_p1
end

def grade_compatible?(p1, p2)
  # If either missing grade, allow
  return true unless p1['grade'] && p2['grade']
  return true unless GRADES[p1['grade']] && GRADES[p2['grade']]

  # Block Freshman-Senior (3 years apart)
  grade_diff = (GRADES[p1['grade']] - GRADES[p2['grade']]).abs
  grade_diff < 3
end

def already_matched?(p1, p2)
  p1['matched_with_emails'].include?(p2['key']) ||
  p2['matched_with_emails'].include?(p1['key'])
end

def can_match?(p1, p2, romantic: true)
  # Both must be checked in
  return false unless p1['checked_in'] && p2['checked_in']

  # Must have phone numbers
  return false if p1['phone'].to_s.empty? || p2['phone'].to_s.empty?

  # Can't match with themselves
  return false if p1['key'] == p2['key']

  # Can't match if already matched before
  return false if already_matched?(p1, p2)

  if romantic
    # Gender preference must match
    return false unless gender_compatible?(p1, p2)

    # Grade compatibility
    return false unless grade_compatible?(p1, p2)
  end

  true
end

def generate_matches
  puts "\n=== GENERATE NEW MATCHES ==="

  checked_in = get_checked_in_participants.values

  if checked_in.size < 2
    puts "\n✗ Need at least 2 people checked in to generate matches"
    puts "  Currently checked in: #{checked_in.size}"
    return
  end

  puts "Generating matches for #{checked_in.size} checked-in participants..."

  # PHASE 0: Special Request Matching
  puts "\n=== PHASE 0: Special Request Matching ==="

  matched = Set.new
  special_matches = []
  special_request_updates = []  # Track updates to apply only if saved

  # Helper to find participant by phone
  def find_by_phone(phone, checked_in)
    phone_normalized = phone.to_s.gsub(/[^0-9]/, '')
    checked_in.find { |p| p['phone'].gsub(/[^0-9]/, '') == phone_normalized }
  end

  # Helper to find participant by name (EXACT match only to prevent false positives)
  def find_by_name(name, checked_in)
    return nil if name.nil? || name.empty?
    name_lower = name.downcase.strip

    # ONLY exact full name match - no fuzzy matching
    # This prevents "Kevin Wu" from matching "Lilly Wu"
    checked_in.find { |p| p['name']&.downcase&.strip == name_lower }
  end

  $state['special_requests'].each do |request|
    next if request['matched']  # Already matched in previous batch

    requester = find_by_phone(request['requester_phone'], checked_in)

    # Match by phone OR exact full name
    requested = nil

    # Try phone first
    if request['requested_phone']
      requested = find_by_phone(request['requested_phone'], checked_in)
    end

    # If not found by phone, try exact name match
    if requested.nil? && request['requested_name']
      requested = find_by_name(request['requested_name'], checked_in)
    end

    # Both must be checked in
    if requester && requested
      # PREVIEW the increment (don't save yet)
      preview_batches = request['batches_together'] + 1
      puts "  #{request['requester_name']} ↔ #{request['requested_name']}: Batch #{preview_batches}/2 together"

      # Track this update to apply later if user confirms
      special_request_updates << { 'request' => request, 'increment' => true }

      # Match on second batch together
      if preview_batches == 2
        # Check if we already added this pair (avoid duplicates for mutual requests)
        already_added = special_matches.any? do |m|
          (m['p1']['key'] == requester['key'] && m['p2']['key'] == requested['key']) ||
          (m['p1']['key'] == requested['key'] && m['p2']['key'] == requester['key'])
        end

        unless already_added
          special_matches << {
            'p1' => requester,
            'p2' => requested,
            'score' => 999,  # High score for display
            'type' => 'special_request'
          }
          matched << requester['key']
          matched << requested['key']
          puts "    ✓ SPECIAL MATCH!"
        else
          puts "    (Already matched via mutual request)"
        end

        # Track that this will be marked as matched
        special_request_updates.last['mark_matched'] = true
      end
    end
  end

  puts "✓ Phase 0: #{special_matches.size} special request matches"

  # Helper function to check if someone has had a friend match before
  def has_friend_match?(person_key)
    $state['match_batches'].any? do |batch|
      batch['matches'].any? do |match|
        # Check both regular friend matches and groups of 3
        if match['type'] == 'friend'
          match['person_a_email'] == person_key || match['person_b_email'] == person_key
        elsif match['type'] == 'friend_group_of_3'
          match['person_a_email'] == person_key ||
          match['person_b_email'] == person_key ||
          match['person_c_email'] == person_key
        else
          false
        end
      end
    end
  end

  # PHASE 1 & 2: Romantic matching with priority for people who had friend matches
  puts "\n=== PHASE 1 & 2: Romantic Matching (Prioritized by friend match history) ==="

  people_with_friend_matches = Set.new(checked_in.select { |p| has_friend_match?(p['key']) }.map { |p| p['key'] })
  puts "#{people_with_friend_matches.size} people had friend matches before (prioritized)"

  # Build all possible romantic pairs
  all_pairs = []
  checked_in.each_with_index do |p1, i|
    checked_in[i+1..-1].each do |p2|
      next unless can_match?(p1, p2, romantic: true)

      # Calculate priority: both had friend matches (2) > one had friend match (1) > neither (0)
      p1_had_friend = people_with_friend_matches.include?(p1['key']) ? 1 : 0
      p2_had_friend = people_with_friend_matches.include?(p2['key']) ? 1 : 0
      priority = p1_had_friend + p2_had_friend

      score = calculate_compatibility_score(p1, p2)
      all_pairs << {
        'p1' => p1,
        'p2' => p2,
        'score' => score,
        'priority' => priority
      }
    end
  end

  # Sort by priority first (descending), then by score (descending)
  all_pairs.sort_by! { |pair| [-pair['priority'], -pair['score']] }

  # matched set already initialized in PHASE 0 (includes special request matches)
  romantic_matches = []

  all_pairs.each do |pair|
    p1_key = pair['p1']['key']
    p2_key = pair['p2']['key']

    next if matched.include?(p1_key) || matched.include?(p2_key)

    romantic_matches << pair
    matched << p1_key
    matched << p2_key
  end

  puts "✓ Romantic matches: #{romantic_matches.size}"
  priority_2 = romantic_matches.count { |p| p['priority'] == 2 }
  priority_1 = romantic_matches.count { |p| p['priority'] == 1 }
  priority_0 = romantic_matches.count { |p| p['priority'] == 0 }
  puts "  - Both had friend matches: #{priority_2}"
  puts "  - One had friend match: #{priority_1}"
  puts "  - Neither had friend match: #{priority_0}"

  # PHASE 3: Friend matching for people who never had a friend match
  # ONLY match people blocked by hard constraints (grade or gender), NOT low compatibility
  puts "\n=== PHASE 3: Friend Matching (Hard constraint failures only) ==="

  unmatched = checked_in.reject { |p| matched.include?(p['key']) }
  eligible_for_friends = unmatched.reject { |p| has_friend_match?(p['key']) }
  already_had_friend = unmatched.size - eligible_for_friends.size

  if already_had_friend > 0
    puts "⚠️  #{already_had_friend} people previously had friend matches but no romantic match available"
    puts "   These people will be unmatched this batch"
  end

  friend_matches = []
  friend_groups_of_three = []

  if eligible_for_friends.size >= 2
    puts "#{eligible_for_friends.size} people eligible for friend matching"

    # Build friend pairs - ONLY for people blocked by romantic filters
    # (gender preference mismatch OR grade incompatibility)
    friend_pairs = []
    eligible_for_friends.each_with_index do |p1, i|
      eligible_for_friends[i+1..-1].each do |p2|
        # Basic checks (checked in, phones, not already matched)
        next if p1['key'] == p2['key']
        next if already_matched?(p1, p2)
        next if p1['phone'].to_s.empty? || p2['phone'].to_s.empty?

        # Check if they were BLOCKED from romantic matching
        gender_blocked = !gender_compatible?(p1, p2)
        grade_blocked = !grade_compatible?(p1, p2)

        # Only make friend match if blocked by hard constraint
        next unless gender_blocked || grade_blocked

        score = calculate_compatibility_score(p1, p2)
        friend_pairs << {
          'p1' => p1,
          'p2' => p2,
          'score' => score,
          'type' => 'friend',
          'reason' => gender_blocked ? 'gender_preference' : 'grade_incompatibility'
        }
      end
    end

    puts "  Found #{friend_pairs.size} pairs blocked by hard constraints (gender/grade)"

    friend_pairs.sort_by! { |pair| -pair['score'] }

    friend_matched = Set.new

    friend_pairs.each do |pair|
      p1_key = pair['p1']['key']
      p2_key = pair['p2']['key']

      next if friend_matched.include?(p1_key) || friend_matched.include?(p2_key)

      friend_matches << pair
      friend_matched << p1_key
      friend_matched << p2_key
      matched << p1_key
      matched << p2_key
    end

    # Handle odd number: make a group of 3
    leftover = eligible_for_friends.reject { |p| friend_matched.include?(p['key']) }
    if leftover.size == 1 && friend_matches.any?
      # Take the last matched pair and add the leftover person to make a group of 3
      last_pair = friend_matches.last
      leftover_person = leftover.first

      friend_groups_of_three << {
        'p1' => last_pair['p1'],
        'p2' => last_pair['p2'],
        'p3' => leftover_person,
        'type' => 'friend_group'
      }

      # Remove the pair from friend_matches since it's now a group
      friend_matches.pop
      matched << leftover_person['key']

      puts "✓ Created 1 friend group of 3 (to handle odd number)"
    end

    puts "✓ Matched #{friend_matches.size} friend pairs"
  elsif eligible_for_friends.size == 1
    puts "⚠️  1 person eligible but needs at least 2 for friend matching"
  end

  total_matches = special_matches.map { |s| s.merge('type' => 'special_request') } + romantic_matches + friend_matches.map { |f| f.merge('type' => 'friend') }

  if total_matches.empty?
    puts "\n✗ No compatible matches found"
    puts "  This can happen if:"
    puts "  - Everyone has already been matched with each other"
    puts "  - Gender preferences don't align"
    puts "  - Grade restrictions eliminate all pairs"
    return
  end

  # Show preview
  puts "\n" + "=" * 60
  puts "MATCH PREVIEW"
  puts "=" * 60

  if special_matches.any?
    puts "\n⭐ Special Request Matches (#{special_matches.size}) - 2nd batch together:"
    special_matches.each_with_index do |pair, i|
      p1 = pair['p1']
      p2 = pair['p2']
      puts "#{i+1}. #{p1['name']} (##{p1['wristband_number']}) ↔ #{p2['name']} (##{p2['wristband_number']}) [SPECIAL REQUEST]"
    end
  end

  if romantic_matches.any?
    puts "\nRomantic Matches (#{romantic_matches.size}):"
    romantic_matches.each_with_index do |pair, i|
      p1 = pair['p1']
      p2 = pair['p2']
      puts "#{i+1}. #{p1['name']} (##{p1['wristband_number']}) ↔ #{p2['name']} (##{p2['wristband_number']}) [Score: #{pair['score']}]"
    end
  end

  if friend_matches.any?
    puts "\nFriend Matches (#{friend_matches.size}) - Due to hard constraints:"
    friend_matches.each_with_index do |pair, i|
      p1 = pair['p1']
      p2 = pair['p2']
      reason = pair['reason'] == 'gender_preference' ? 'Gender preference' : 'Grade (Freshman-Senior)'
      puts "#{i+1}. #{p1['name']} (##{p1['wristband_number']}) ↔ #{p2['name']} (##{p2['wristband_number']}) [#{reason}] [Score: #{pair['score']}]"
    end
  end

  if friend_groups_of_three.any?
    puts "\nFriend Groups of 3 (#{friend_groups_of_three.size}):"
    friend_groups_of_three.each_with_index do |group, i|
      p1 = group['p1']
      p2 = group['p2']
      p3 = group['p3']
      puts "#{i+1}. #{p1['name']} (##{p1['wristband_number']}) ↔ #{p2['name']} (##{p2['wristband_number']}) ↔ #{p3['name']} (##{p3['wristband_number']})"
    end
  end

  still_unmatched = checked_in.size - (matched.size)
  if still_unmatched > 0
    puts "\n⚠ #{still_unmatched} people will remain unmatched this batch"
  end

  print "\nSave these matches? (yes/no): "
  confirm = gets.chomp.downcase

  return unless confirm == 'yes' || confirm == 'y'

  # Save matches to state
  batch_number = $state['match_batches'].size + 1
  batch = {
    'batch_number' => batch_number,
    'generated_at' => Time.now.utc.iso8601,
    'sent_at' => nil,
    'matches' => []
  }

  # Save all pairs (special requests, romantic, and friend pairs of 2)
  (special_matches + romantic_matches + friend_matches).each do |pair|
    p1 = pair['p1']
    p2 = pair['p2']
    type = pair['type'] || 'romantic'

    # Update participant state
    $state['participants'][p1['key']]['matched_with_emails'] << p2['key']
    $state['participants'][p2['key']]['matched_with_emails'] << p1['key']

    # Add to batch
    batch['matches'] << {
      'person_a_email' => p1['key'],
      'person_a_name' => p1['name'],
      'person_a_wristband' => p1['wristband_number'],
      'person_a_phone' => p1['phone'],
      'person_b_email' => p2['key'],
      'person_b_name' => p2['name'],
      'person_b_wristband' => p2['wristband_number'],
      'person_b_phone' => p2['phone'],
      'type' => type,
      'compatibility_score' => pair['score']
    }
  end

  # Save groups of 3
  friend_groups_of_three.each do |group|
    p1 = group['p1']
    p2 = group['p2']
    p3 = group['p3']

    # Update participant state (everyone matched with everyone in the group)
    $state['participants'][p1['key']]['matched_with_emails'] << p2['key']
    $state['participants'][p1['key']]['matched_with_emails'] << p3['key']
    $state['participants'][p2['key']]['matched_with_emails'] << p1['key']
    $state['participants'][p2['key']]['matched_with_emails'] << p3['key']
    $state['participants'][p3['key']]['matched_with_emails'] << p1['key']
    $state['participants'][p3['key']]['matched_with_emails'] << p2['key']

    # Add to batch (store as special group type)
    batch['matches'] << {
      'person_a_email' => p1['key'],
      'person_a_name' => p1['name'],
      'person_a_wristband' => p1['wristband_number'],
      'person_a_phone' => p1['phone'],
      'person_b_email' => p2['key'],
      'person_b_name' => p2['name'],
      'person_b_wristband' => p2['wristband_number'],
      'person_b_phone' => p2['phone'],
      'person_c_email' => p3['key'],
      'person_c_name' => p3['name'],
      'person_c_wristband' => p3['wristband_number'],
      'person_c_phone' => p3['phone'],
      'type' => 'friend_group_of_3',
      'compatibility_score' => 0
    }
  end

  # Apply special request updates (only now that user confirmed)
  special_request_updates.each do |update|
    update['request']['batches_together'] += 1
    update['request']['matched'] = true if update['mark_matched']
  end

  $state['match_batches'] << batch
  $state['last_operation'] = 'generate_matches'
  save_state

  puts "\n✓ Saved #{batch['matches'].size} matches to Batch ##{batch_number}"
  puts "  Use option 5 to send via Twilio"
end

# ============================================================================
# TWILIO INTEGRATION
# ============================================================================

def send_matches
  puts "\n=== SEND MATCHES VIA TWILIO ==="

  # 🔒 SAFETY LOCKOUT - DISABLED FOR TESTING 🔒
  puts "\n" + "=" * 60
  puts "⚠️  TWILIO SENDING IS CURRENTLY DISABLED"
  puts "=" * 60
  puts "\nThis is a safety feature to prevent accidental messages."
  puts "Messages will NOT be sent even if you confirm."
  puts "\nTo enable sending on Friday:"
  puts "  1. Open bridge_matcher.rb"
  puts "  2. Find the send_matches function (line ~655)"
  puts "  3. Comment out or remove the safety lockout section"
  puts "\n❌ No messages will be sent."

  # Still generate the webpage as backup
  puts "\n📱 Generating backup webpage..."
  unsent_batches = $state['match_batches'].select { |b| !b['sent_at'] }
  if unsent_batches.any?
    batch = unsent_batches.last
    generate_matches_webpage($state, batch['batch_number'])
    puts "\n✓ Backup webpage ready: matches_display.html"
    puts "  You can open this in a browser to see all matches"
  end

  return

  # Check for Twilio credentials
  unless ENV['TWILIO_ACCOUNT_SID'] && ENV['TWILIO_AUTH_TOKEN'] && ENV['TWILIO_PHONE_NUMBER']
    puts "\n✗ Twilio credentials not configured!"
    puts "  Please create a .env file with:"
    puts "    TWILIO_ACCOUNT_SID=your_sid"
    puts "    TWILIO_AUTH_TOKEN=your_token"
    puts "    TWILIO_PHONE_NUMBER=+1234567890"
    return
  end

  # Find unsent batches
  unsent_batches = $state['match_batches'].select { |b| !b['sent_at'] }

  if unsent_batches.empty?
    puts "\n✗ No unsent matches to send"
    puts "  Generate matches first (option 4)"
    return
  end

  batch = unsent_batches.last
  matches = batch['matches']

  puts "\nBatch ##{batch['batch_number']} - #{matches.size} matches to send"
  puts "Generated at: #{batch['generated_at']}"

  # Show preview
  puts "\nMessage preview:"
  sample_romantic = matches.find { |m| m['type'] == 'romantic' }
  sample_friend = matches.find { |m| m['type'] == 'friend' }

  if sample_romantic
    puts "\nRomantic match example:"
    puts "  To: #{sample_romantic['person_a_phone']}"
    puts "  Message: \"Your Bridge match is ##{sample_romantic['person_b_wristband']}!\""
  end

  if sample_friend
    puts "\nFriend match example:"
    puts "  To: #{sample_friend['person_a_phone']}"
    puts "  Message: \"We didn't find a romantic interest for you this round, but you'd make great friends with ##{sample_friend['person_b_wristband']}! You'll be prioritized for a romantic match next round.\""
  end

  print "\nSend #{matches.size * 2} messages? (yes/no): "
  confirm = gets.chomp.downcase

  return unless confirm == 'yes' || confirm == 'y'

  # Try to require twilio-ruby
  begin
    require 'twilio-ruby'
  rescue LoadError
    puts "\n✗ twilio-ruby gem not installed!"
    puts "  Run: gem install twilio-ruby"
    return
  end

  # Initialize Twilio client
  client = Twilio::REST::Client.new(
    ENV['TWILIO_ACCOUNT_SID'],
    ENV['TWILIO_AUTH_TOKEN']
  )

  puts "\nSending messages..."

  sent = 0
  failed = 0
  failed_sends = []

  matches.each do |match|
    if match['type'] == 'friend_group_of_3'
      # Handle group of 3 - send to all three people
      people = [
        { 'name' => match['person_a_name'], 'phone' => match['person_a_phone'], 'wristband' => match['person_a_wristband'],
          'others' => [match['person_b_wristband'], match['person_c_wristband']] },
        { 'name' => match['person_b_name'], 'phone' => match['person_b_phone'], 'wristband' => match['person_b_wristband'],
          'others' => [match['person_a_wristband'], match['person_c_wristband']] },
        { 'name' => match['person_c_name'], 'phone' => match['person_c_phone'], 'wristband' => match['person_c_wristband'],
          'others' => [match['person_a_wristband'], match['person_b_wristband']] }
      ]

      people.each do |person|
        message = "We didn't find a romantic interest for you this round, but you'd make great friends with ##{person['others'][0]} and ##{person['others'][1]}! You'll be prioritized for a romantic match next round."

        begin
          client.messages.create(
            from: ENV['TWILIO_PHONE_NUMBER'],
            to: person['phone'],
            body: message
          )
          sent += 1
          print "."
        rescue => e
          puts "\n✗ Failed to send to #{person['name']}: #{e.message}"
          failed += 1
          failed_sends << {
            'name' => person['name'],
            'phone' => person['phone'],
            'wristband' => person['wristband'],
            'match_wristband' => person['others'].join(', '),
            'error' => e.message
          }
        end
        sleep 0.1
      end
    else
      # Regular pair (romantic or friend pair of 2)
      # Send to person A
      message_a = if match['type'] == 'romantic'
        "Your Bridge match is ##{match['person_b_wristband']}!"
      else
        "We didn't find a romantic interest for you this round, but you'd make great friends with ##{match['person_b_wristband']}! You'll be prioritized for a romantic match next round."
      end

      begin
        client.messages.create(
          from: ENV['TWILIO_PHONE_NUMBER'],
          to: match['person_a_phone'],
          body: message_a
        )
        sent += 1
        print "."
      rescue => e
        puts "\n✗ Failed to send to #{match['person_a_name']}: #{e.message}"
        failed += 1
        failed_sends << {
          'name' => match['person_a_name'],
          'phone' => match['person_a_phone'],
          'wristband' => match['person_a_wristband'],
          'match_wristband' => match['person_b_wristband'],
          'error' => e.message
        }
      end

      # Send to person B
      message_b = if match['type'] == 'romantic'
        "Your Bridge match is ##{match['person_a_wristband']}!"
      else
        "We didn't find a romantic interest for you this round, but you'd make great friends with ##{match['person_a_wristband']}! You'll be prioritized for a romantic match next round."
      end

      begin
        client.messages.create(
          from: ENV['TWILIO_PHONE_NUMBER'],
          to: match['person_b_phone'],
          body: message_b
        )
        sent += 1
        print "."
      rescue => e
        puts "\n✗ Failed to send to #{match['person_b_name']}: #{e.message}"
        failed += 1
        failed_sends << {
          'name' => match['person_b_name'],
          'phone' => match['person_b_phone'],
          'wristband' => match['person_b_wristband'],
          'match_wristband' => match['person_a_wristband'],
          'error' => e.message
        }
      end

      # Small delay to avoid rate limiting
      sleep 0.1
    end
  end

  puts "\n\n✓ Sent #{sent} messages"
  puts "✗ Failed #{failed} messages" if failed > 0

  # Save failed sends to file
  if failed_sends.any?
    File.open('failed_sends.txt', 'a') do |f|
      f.puts "\n" + "=" * 60
      f.puts "Batch ##{batch['batch_number']} - #{Time.now}"
      f.puts "=" * 60
      failed_sends.each do |fail|
        f.puts "#{fail['name']} (Wristband ##{fail['wristband']})"
        f.puts "  Phone: #{fail['phone']}"
        f.puts "  Match: Wristband ##{fail['match_wristband']}"
        f.puts "  Error: #{fail['error']}"
        f.puts
      end
    end
    puts "⚠️  Failed sends logged to: failed_sends.txt"
  end

  # Mark batch as sent
  batch['sent_at'] = Time.now.utc.iso8601
  $state['last_operation'] = 'send_matches'
  save_state

  puts "\n✓ Batch ##{batch['batch_number']} marked as sent"

  # Generate backup webpage
  puts "\n📱 Generating backup webpage..."
  generate_matches_webpage($state, batch['batch_number'])
  puts "✓ Webpage updated: matches_display.html"
  puts "  Open this in a browser if you need to reference matches"
end

# ============================================================================
# EXPORT
# ============================================================================

def export_results
  puts "\n=== EXPORT RESULTS ==="

  if $state['match_batches'].empty?
    puts "\n✗ No matches to export yet"
    return
  end

  CSV.open(EXPORT_FILE, 'w') do |csv|
    csv << ['Batch', 'Person 1', 'Wristband 1', 'Person 2', 'Wristband 2', 'Type', 'Score', 'Generated At', 'Sent At']

    $state['match_batches'].each do |batch|
      batch['matches'].each do |match|
        csv << [
          batch['batch_number'],
          match['person_a_name'],
          match['person_a_wristband'],
          match['person_b_name'],
          match['person_b_wristband'],
          match['type'],
          match['compatibility_score'],
          batch['generated_at'],
          batch['sent_at'] || 'Not sent'
        ]
      end
    end
  end

  puts "\n✓ Exported #{$state['match_batches'].sum { |b| b['matches'].size }} matches to #{EXPORT_FILE}"
end

# ============================================================================
# UTILITY
# ============================================================================

def reset_system
  puts "\n=== RESET SYSTEM ==="
  puts "\n⚠ WARNING: This will:"
  puts "  - Clear all check-ins"
  puts "  - Clear all matches"
  puts "  - Reset wristband numbers"
  puts "  - Reset special request states"
  puts "  - Keep participant data"

  print "\nType 'RESET' to confirm: "
  confirm = gets.chomp

  return unless confirm == 'RESET'

  $state['match_batches'] = []
  $state['next_wristband_number'] = 1
  $state['next_walkin_wristband_number'] = 250

  $state['participants'].each do |key, p|
    p['checked_in'] = false
    p['wristband_number'] = nil
    p['matched_with_emails'] = []
  end

  # Reset special requests to unmatched state
  $state['special_requests']&.each do |request|
    request['batches_together'] = 0
    request['matched'] = false
  end

  $state['last_operation'] = 'reset'
  save_state

  puts "\n✓ System reset complete"
  puts "  - All special requests reset (batches_together: 0, matched: false)"
end

def reload_data
  puts "\n=== RELOAD PARTICIPANT DATA ==="
  puts "\nThis will reload #{MERGED_CSV} and merge with existing state."
  puts "Existing check-ins and matches will be preserved."

  print "\nContinue? (yes/no): "
  confirm = gets.chomp.downcase

  return unless confirm == 'yes' || confirm == 'y'

  old_count = $participants.size
  load_participants
  merge_state_with_participants
  new_count = $participants.size

  puts "\n✓ Reloaded participant data"
  puts "  Previous: #{old_count} participants"
  puts "  Current: #{new_count} participants"
  puts "  New: #{new_count - old_count}" if new_count > old_count
end

# ============================================================================
# MAIN
# ============================================================================

def main
  puts "=" * 60
  puts "BRIDGE PUB MATCHING SYSTEM"
  puts "=" * 60

  # Load data
  unless File.exist?(MERGED_CSV)
    puts "\n✗ Error: #{MERGED_CSV} not found!"
    puts "  Run: ruby merge_data.rb"
    exit 1
  end

  load_participants
  load_state
  load_special_requests
  merge_state_with_participants

  puts "\n✓ System ready"
  puts "  Participants: #{$participants.size}"
  puts "  Checked in: #{get_checked_in_participants.size}"
  puts "  Batches sent: #{$state['match_batches'].count { |b| b['sent_at'] }}"

  # Start menu
  main_menu
end

# Run
main if __FILE__ == $0
