# Bridge Pub Matching System - Implementation Plan

---

## ⚠️ CRITICAL WARNING - TESTING MODE ⚠️

**🚨 DO NOT SEND MESSAGES BEFORE THE EVENT! 🚨**

**While testing and preparing:**
- ✅ Generate matches to test the algorithm (Option 4)
- ✅ Review match quality and compatibility scores
- ✅ Check in test participants
- ❌ **DO NOT USE OPTION 5 (SEND VIA TWILIO)**
- ❌ **DO NOT SEND REAL MESSAGES TO PARTICIPANTS**

**Only send messages on Friday night during the actual event!**

Messages cannot be unsent. Test thoroughly but DO NOT hit send until the party.

---

## Overview

A Ruby-based matching system for the Bridge dating app event at Rice University's pub. The system manages participant check-ins, generates optimal romantic matches across 3 rounds throughout the night, and sends matches via Twilio SMS.

**Event Details:**
- Date: Friday
- Time: 10:00 PM - 1:00 AM
- Match drops: Flexible - send whenever you want to energize the party
- Venue: Pub at Rice
- Match limit: UNLIMITED - generate and send as many batches as you want!

## System Architecture

### Files Structure
```
bridge-pub/
├── typeformbridgepub.csv          # Original survey data
├── waitlist_duplicate_rows.csv    # Additional contact info
├── merged_participants.csv        # Clean merged data (✅ created)
├── .env                           # Twilio credentials
├── bridge_matcher.rb              # Main Ruby script (to build)
├── bridge_state.json              # Runtime state (auto-generated)
└── PLAN.md                        # This file
```

### Core Components

#### 1. Data Layer
- **Source:** `merged_participants.csv` (initial: 145 participants, will grow)
- **Preprocessing:** Re-runnable merge script for new survey responses
- **Data Updates:** System supports reloading CSV with new participants mid-event
- **Missing Data Handling:**
  - Missing phones: Skip from matching (can't send SMS)
  - Missing emails: Use name as identifier
  - Missing grades: Skip grade-based filters for these participants

**Updating Data Mid-Event:**
When new survey responses come in:
1. Download new `typeformbridgepub.csv` from Typeform
2. Run: `ruby merge_data.rb` to create updated `merged_participants.csv`
3. In main script, use Menu Option 10: "Reload participant data"
4. System will:
   - Load new participants
   - Preserve existing check-ins and matches
   - Make new participants available for future rounds
   - Use email as stable identifier to merge state

#### 2. State Management
**File:** `bridge_state.json`

**Stable Identifier:** Email address (or name if email missing)
- State keyed by email to preserve data across CSV reloads
- When new CSV loaded, existing state merged by matching emails
- New participants added, existing participants' state preserved

**Structure:**
```json
{
  "match_batches": [
    {
      "batch_number": 1,
      "generated_at": "2026-02-07T23:00:00Z",
      "sent_at": "2026-02-07T23:01:00Z",
      "matches": [
        {
          "person_a_email": "john_doe@rice.edu",
          "person_b_email": "jane_smith@rice.edu",
          "type": "romantic",
          "compatibility_score": 85
        }
      ]
    }
  ],
  "participants": {
    "john_doe_email@rice.edu": {
      "name": "John Doe",
      "email": "john_doe_email@rice.edu",
      "phone": "1234567890",
      "checked_in": true,
      "wristband_number": 1,
      "matched_with_emails": ["jane_smith@rice.edu", "alice_jones@rice.edu"]
    }
  },
  "next_wristband_number": 3,
  "last_operation": "check_in",
  "last_updated": "2026-02-07T22:30:00Z"
}
```

**State Persistence:**
- Saved after every operation
- Enables crash recovery
- Tracks who's been matched together to prevent duplicate pairings
- No limit on number of match batches
- No limit on matches per person
- Continue generating matches as long as compatible pairs exist

#### 3. CLI Menu System

**Main Menu:**
```
=== BRIDGE PUB MATCHER ===
Batches sent: X | Total matches: Y | Checked in: Z

1. Check in participant
2. Check out participant
3. View current status
4. Generate new matches
5. Send matches via Twilio
6. Export results
7. Reset system (USE WITH CAUTION)
8. Reload participant data (for new survey responses)
9. Exit

Choose option:
```

**Menu Options Explained:**

**Option 1: Check In**
- Prompt for name or email
- Search participants
- Assign next available wristband number
- Mark as present
- Save state

**Option 2: Check Out**
- Prompt for name/email/wristband number
- Mark as absent
- Remove from matching pool for future rounds
- Keep existing matches
- Save state

**Option 3: View Status**
Display:
- Total batches sent: X
- Total participants: X
- Checked in: X
- Total matches made: X
- People with most matches: [Name (X matches)]
- People never matched: X
- List of checked-in participants with wristband numbers and match count

**Option 4: Generate New Matches**
- Run matching algorithm on all available participants
- Excludes anyone with 3 matches already
- Excludes anyone matched in previous batches (no re-matching)
- Display matches before confirmation
- Shows compatibility scores
- Ask for confirmation before saving
- Update state
- Can be run as many times as needed during event

**Option 5: Send via Twilio**
- Show most recently generated (unsent) matches
- Display message preview
- Confirm before sending
- Send SMS to all matched participants
- Log successes/failures
- Mark batch as "sent" to prevent re-sending

**Option 6: Export Results**
- Generate CSV with all matches across all batches
- Format: Batch#, Person1, Wristband1, Person2, Wristband2, Type, Timestamp

**Option 7: Reset System**
- Double confirmation required
- Clear all check-ins and matches
- Keep participant data

**Option 8: Reload Participant Data**
- Use when new survey responses come in
- Download new CSV from Typeform
- Run `ruby merge_data.rb` first
- Then select this option
- System will:
  - Reload `merged_participants.csv`
  - Preserve all existing state (check-ins, matches, wristband numbers)
  - Add new participants to available pool
  - Use email as merge key to maintain consistency
- Display: "Loaded X new participants"

## Matching Algorithm

### Hard Filters (Must Pass)

1. **Both participants present** - checked in and not checked out
2. **Phone number available** - need phone to send match
3. **Not previously matched together** - these two people haven't been matched before
4. **Gender preference match** - bidirectional compatibility
   - Person A's gender must be in Person B's preferences
   - Person B's gender must be in Person A's preferences
   - Multiple preferences allowed (e.g., "Male, Female" matches both)
5. **Grade compatibility** - NO freshman-senior matches
   - Exception: If either person has no grade data, skip this filter
   - Allowed: Freshman-Sophomore, Freshman-Junior, Sophomore-Junior, Sophomore-Senior, Junior-Senior

### Compatibility Scoring

**Total possible score: ~130 points**

```ruby
def calculate_compatibility_score(person_a, person_b)
  score = 0

  # 1. Grade Proximity (0-20 points)
  if both_have_grades?(person_a, person_b)
    grade_diff = grade_difference(person_a, person_b)
    score += case grade_diff
    when 0 then 20  # Same grade
    when 1 then 10  # Adjacent (e.g., Fresh-Soph)
    when 2 then 5   # 2 apart (e.g., Fresh-Junior)
    else 0
    end
  end

  # 2. School Match (0-10 points)
  if same_school?(person_a, person_b)
    score += 10
  end

  # 3. Ideal Friday Night (0-15 points)
  if same_ideal_friday?(person_a, person_b)
    score += 15
  end

  # 4. Decision Guide: Emotion vs Logic (0-15 points)
  if same_decision_guide?(person_a, person_b)
    score += 15
  end

  # 5. Plan vs Spontaneous (0-15 points)
  if same_plan_preference?(person_a, person_b)
    score += 15
  end

  # 6. Fitness Importance (0-20 points) - WEIGHTED HIGHER
  fitness_diff = fitness_importance_difference(person_a, person_b)
  score += case fitness_diff
  when 0 then 20  # Exact match
  when 1 then 10  # One level apart
  else 0
  end

  # 7. Important Value (0-20 points)
  if same_important_value?(person_a, person_b)
    score += 20
  end

  # 8. Reading Habit (0-10 points)
  if same_reading_habit?(person_a, person_b)
    score += 10
  end

  return score
end
```

### Matching Algorithm Steps

**Algorithm: Maximum Weighted Bipartite Matching**

1. **Build Eligible Pool**
   - Get all checked-in participants
   - Filter out those with 3 matches
   - Filter out those already matched this round
   - Filter out those missing phone numbers

2. **Generate Compatibility Matrix**
   - For each pair (A, B):
     - Check hard filters
     - If pass, calculate compatibility score
     - Store score in matrix
   - Result: NxN matrix of compatibility scores (0 if incompatible)

3. **Find Optimal Matching**
   - Use greedy maximum weighted matching
   - Algorithm:
     ```
     while unmatched_people_exist:
       find highest scoring compatible pair (A, B)
       if no pairs left: break
       match A with B
       remove A and B from pool
     ```
   - This ensures bidirectional matches
   - Maximizes total compatibility

4. **Handle Unmatched Participants**
   - For people still unmatched after romantic matching
   - Re-run algorithm WITHOUT gender preference filter
   - Mark matches as "friend" type
   - Same compatibility scoring otherwise

5. **Return Matches**
   - Format: Array of {person_a, person_b, score, type}
   - Sorted by score (highest first)

### Example Matching Scenario

**Batch 1:**
- 80 people checked in
- After filtering: 78 eligible (2 missing phones)
- Compatibility matrix: 78x78
- Result: 30 romantic pairs matched (60 people)
- Remaining: 18 people
- Friend matching: 7 friend pairs (14 people)
- Still unmatched: 4 people (wait for next batch)

**Batch 2:**
- 10 more people checked in (90 total)
- Eligible: Everyone who hasn't been matched with each other yet
- New compatible pairs after excluding previous matches: ~35 pairs
- Result: 35 romantic pairs (70 people)
- Friend matching: 8 friend pairs (16 people)
- 4 people unmatched this round

**Batch 3:**
- 5 more people checked in (95 total)
- Eligible: Everyone, excluding people who were already matched together
- Compatible pairs remaining: ~40 pairs
- Result: 40 romantic pairs (80 people)
- Continue as long as you want!

**Later batches:**
- Party still going? Generate more!
- Algorithm automatically excludes previous pairings
- Each person can get matched multiple times with different people
- No upper limit!

## Twilio Integration

### Setup

**Environment Variables (they are in .env):**
```
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890
```

**Ruby Gem:**
```ruby
require 'twilio-ruby'

client = Twilio::REST::Client.new(
  ENV['TWILIO_ACCOUNT_SID'],
  ENV['TWILIO_AUTH_TOKEN']
)
```

### Message Templates

**Romantic Match:**
```
Your Bridge match is {name}, sign in #{wristband_number}!
```

**Friend Match:**
```
We didn't find a romantic interest for you this round, but you'd make great friends with {name}, sign in #{wristband_number}!
```

### Sending Logic

```ruby
def send_match_notification(person, matched_with, type)
  message_body = if type == "romantic"
    "Your Bridge match is #{matched_with[:name]}, sign in ##{matched_with[:wristband]}!"
  else
    "We didn't find a romantic interest for you this round, but you'd make great friends with #{matched_with[:name]}, sign in ##{matched_with[:wristband]}!"
  end

  client.messages.create(
    from: ENV['TWILIO_PHONE_NUMBER'],
    to: person[:phone],
    body: message_body
  )
end
```

### Error Handling
- Retry failed messages (max 3 attempts)
- Log all send attempts
- Display summary: X sent, Y failed
- Save failed numbers for manual follow-up

## Data Structure Details

### Participant Fields (from CSV)

**Required for matching:**
- Name
- Phone number
- Gender
- Gender preference(s)

**Optional but used in scoring:**
- Email
- Grade
- School
- Ideal Friday night
- Decision guide (emotion/logic)
- Plan vs spontaneous
- Fitness importance
- Important value
- Reading habit

**Survey-specific field (deferred):**
- Special request (not implemented in v1)

### Grade Mapping

```ruby
GRADES = {
  "Freshman" => 1,
  "Sophomore" => 2,
  "Junior" => 3,
  "Senior" => 4
}

# Grade difference calculation
def grade_difference(person_a, person_b)
  (GRADES[person_a.grade] - GRADES[person_b.grade]).abs
end

# Grade compatibility check
def grades_compatible?(person_a, person_b)
  # If either missing grade, allow
  return true if person_a.grade.nil? || person_b.grade.nil?

  # Block Freshman-Senior
  diff = grade_difference(person_a, person_b)
  diff < 3  # Max 2 years apart
end
```

### Gender Preference Handling

**CSV Structure:**
- Column 8: "Male" if selected
- Column 9: "Female" if selected
- Column 10: "Non-binary" if selected

**Parse Logic:**
```ruby
def parse_gender_preferences(row)
  prefs = []
  prefs << "Male" if row[7] == "Male"
  prefs << "Female" if row[8] == "Female"
  prefs << "Non-binary" if row[9] == "Non-binary"
  prefs
end

def gender_compatible?(person_a, person_b)
  # A's gender must be in B's preferences
  a_in_b = person_b.gender_preferences.include?(person_a.gender)

  # B's gender must be in A's preferences
  b_in_a = person_a.gender_preferences.include?(person_b.gender)

  a_in_b && b_in_a
end
```

## Error Handling & Recovery

### Crash Recovery

**On startup:**
1. Check if `bridge_state.json` exists
2. If yes: Load state and continue from last operation
3. If no: Initialize new state

**State checkpoints:**
- After every check-in/out
- After generating matches
- After sending messages
- Before advancing rounds

### Validation Checks

**Before generating matches:**
- At least 2 people checked in
- Warn if very few compatible pairs remain (most people already matched together)

**Before sending messages:**
- Unsent matches exist
- All matched participants still checked in
- Twilio credentials configured
- Confirm before sending (can't unsend!)

### Edge Cases

1. **Odd number of participants:** Some people won't get matched
2. **Gender imbalance:** Use friend matching for extras
3. **No compatible matches:** Friend matching fallback
4. **Person checks out mid-round:** Keep in current round matches, exclude from future
5. **Duplicate check-in:** Warn and skip
6. **Invalid wristband lookup:** Show error, prompt again

## Usage Instructions

### Setup (One-time)

1. **Install Twilio gem:**
   ```bash
   gem install twilio-ruby
   ```

2. **Create .env file:**
   ```bash
   # .env
   TWILIO_ACCOUNT_SID=your_sid_here
   TWILIO_AUTH_TOKEN=your_token_here
   TWILIO_PHONE_NUMBER=+15551234567
   ```

3. **Verify data:**
   ```bash
   ruby bridge_matcher.rb
   # Will load and validate merged_participants.csv
   ```

### Event Night Workflow

**Before event (9:00 PM):**
1. Start script: `ruby bridge_matcher.rb`
2. Verify participant count
3. Have wristbands numbered 1-145+ ready

**During event (10:00 PM - 1:00 AM):**

**Ongoing: Check-ins**
- Menu Option 1: Check in participants as they arrive
- Hand out numbered wristbands
- Keep checking people in throughout the night

**Whenever you want to energize the party:**
1. Menu Option 4: Generate new matches
2. Review matches and compatibility scores
3. Confirm
4. Menu Option 5: Send via Twilio
5. Watch the excitement unfold!

**Repeat as many times as you want:**
- Party feeling dry? Generate more matches!
- New people arrived? Check them in and generate matches!
- Energy low? Send another batch!
- People want more matches? Send more!
- No limit - keep the energy going all night!

**Post-event:**
- Menu Option 7: Export results
- Save all files for analysis

**Updating Data Mid-Event (as new responses come in):**
1. Download latest `typeformbridgepub.csv` from Typeform
2. (Optional) Update `waitlist_duplicate_rows.csv` if you have new waitlist data
3. Run: `ruby merge_data.rb`
4. In main script, Menu Option 9: Reload participant data
5. New participants now available for check-in
6. Existing check-ins and matches preserved

### Troubleshooting

**Script crashes:**
- Restart: `ruby bridge_matcher.rb`
- State automatically restored
- Continue from where you left off

**Twilio fails:**
- Check .env credentials
- Check phone number format (+1XXXXXXXXXX)
- Check Twilio account balance

**Wrong match generated:**
- DO NOT regenerate (will change all matches)
- Manually send correction via Twilio dashboard
- Note for post-event analysis

**New survey responses arrive:**
1. Download updated `typeformbridgepub.csv`
2. Run `ruby merge_data.rb` (safe to re-run)
3. In main script: Menu Option 9 (Reload data)
4. New participants available for check-in
5. All existing state preserved

**Person in state but not in new CSV:**
- Keep in state (they were checked in)
- Still eligible for matching
- Their data frozen at last known state

## Technical Specifications

### Dependencies
- Ruby 2.6.10+ (✅ installed)
- Standard library: CSV, JSON, FileUtils
- External gem: twilio-ruby

### Performance
- Matching algorithm: O(n²) for compatibility matrix
- Expected runtime: < 1 second for 145 participants
- State file size: ~50KB

### Data Privacy
- Phone numbers only used for Twilio
- No data sent to external services (except Twilio)
- State file contains PII - delete after event

### Limitations
- No special request matching (deferred to v2)
- No manual match editing (regenerate or manual Twilio)
- No undo for sent messages
- People can't be matched with the same person twice (but unlimited total matches)

## Future Enhancements (Post-Event)

1. **Special request boosting** - Boost compatibility score for requested matches
2. **Manual match overrides** - Allow operator to create custom matches
3. **Match analytics** - Success rates, compatibility score distributions
4. **Web interface** - Replace CLI with web UI
5. **Real-time updates** - WebSocket for live match status
6. **Photo integration** - Include photos in match notifications

---

## Implementation Checklist

- [✅] Data merge completed
- [ ] Main script: `bridge_matcher.rb`
  - [ ] CSV parsing
  - [ ] State management
  - [ ] CLI menu
  - [ ] Check-in/out logic
  - [ ] Matching algorithm
  - [ ] Twilio integration
  - [ ] Error handling
- [ ] Testing
  - [ ] Test with sample data
  - [ ] Test state persistence
  - [ ] Test Twilio (1-2 test messages)
- [ ] .env setup (user provides credentials)
- [ ] Ready for event

---

**Questions or concerns?** Review this plan before implementation begins.
