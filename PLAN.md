# Bridge Pub Matching System - Implementation Plan
**Last Updated:** Feb 5, 2026
**Event:** Friday 10pm-1am
**Current Participants:** 195

---

## ⚠️ CRITICAL WARNING - TESTING MODE ⚠️

**🚨 DO NOT SEND MESSAGES BEFORE THE EVENT! 🚨**

**Twilio Safety Lockout Status:** ENABLED (line ~1274 in bridge_matcher.rb)
- **MUST REMOVE BEFORE FRIDAY**
- Search for "SAFETY LOCKOUT" and delete that section

**While testing and preparing:**
- ✅ Generate matches to test the algorithm (Option 4)
- ✅ Review match quality and compatibility scores
- ✅ Check in test participants
- ❌ **DO NOT USE OPTION 5 (SEND VIA TWILIO) - IT'S DISABLED ANYWAY**
- ❌ **DO NOT SEND REAL MESSAGES TO PARTICIPANTS**

**Only send messages on Friday night during the actual event!**

Messages cannot be unsent. Test thoroughly but DO NOT hit send until the party.

---

## System Overview

A Ruby-based matching system for the Bridge dating app event at Rice University's pub. The system manages participant check-ins, generates optimal romantic matches with special request support, and sends matches via Twilio SMS.

**Event Details:**
- Date: Friday
- Time: 10:00 PM - 1:00 AM
- Venue: Pub at Rice
- Expected turnout: 80-120 people
- Walk-ins expected: ~50 people
- Match batches: 3-4 during the night

---

## Files Structure

```
bridge-pub/
├── current_bridge_pub_complete.csv    # Master participant list (195 people)
├── special_requests.json              # 33 special requests
├── bridge_matcher.rb                  # Main Ruby script
├── bridge_state.json                  # Runtime state (auto-generated)
├── add_new_registrations.rb           # Merge new walk-in registrations
├── normalize_phones.rb                # Phone standardization utility
├── validate_special_requests.rb       # Check which special requests work
├── debug_special_requests.rb          # Debug special request matching
├── .env                               # Twilio credentials
├── PLAN.md                            # This file
├── COMPREHENSIVE_AUDIT.md             # Full system audit
└── FRIDAY_CHECKLIST.md                # Pre-event checklist
```

---

## Core Components

### 1. Data Layer

**Master File:** `current_bridge_pub_complete.csv` (195 participants)
- All phone numbers standardized to 10 digits
- 65 people missing grade (intentionally allowed)
- 1 person (Ian) has 9-digit phone (needs manual fix)

**Walk-In Workflow:**
1. Walk-in fills Typeform
2. Export new CSV from Typeform
3. Run: `ruby add_new_registrations.rb new_export.csv`
4. Script validates phones (must be exactly 10 digits)
5. Merges with current_bridge_pub_complete.csv
6. Option 8 in main script: Reload participant data
7. Option 11: Check in walk-in (separate wristband range)

**Phone Validation:**
- add_new_registrations.rb validates all phones to exactly 10 digits
- Skips and warns about invalid phones (prevents Ian-style issues)

### 2. Special Requests System

**File:** `special_requests.json` (33 requests)

**How It Works:**
- Matches by **phone number** (exact) OR **exact full name** (case-insensitive)
- Requires BOTH people checked in for TWO consecutive batches
- Batch 1: Counter increments 0→1 (no match)
- Batch 2: Counter increments 1→2 (**AUTO-MATCH**)
- Deduplicates mutual requests (A→B and B→A create only 1 match)
- Matches happen in Phase 0 (before all filters)

**Current Status:**
- 6 valid requests (both people in system)
- 27 waiting on walk-ins to register

**Validation:**
Run `ruby validate_special_requests.rb` to see which requests will work

### 3. State Management

**File:** `bridge_state.json`

**Structure:**
```json
{
  "match_batches": [
    {
      "batch_number": 1,
      "generated_at": "2026-02-05T23:00:00Z",
      "sent_at": "2026-02-05T23:01:00Z",
      "matches": [
        {
          "person_a_email": "john@rice.edu",
          "person_a_wristband": 42,
          "person_b_email": "jane@rice.edu",
          "person_b_wristband": 87,
          "type": "romantic",
          "compatibility_score": 85
        }
      ]
    }
  ],
  "participants": {
    "john@rice.edu": {
      "name": "John Doe",
      "email": "john@rice.edu",
      "phone": "7135551234",
      "checked_in": true,
      "wristband_number": 42,
      "matched_with_emails": ["jane@rice.edu"]
    }
  },
  "special_requests": [...],
  "next_wristband_number": 195,
  "next_walkin_wristband_number": 250,
  "last_operation": "generate_matches",
  "last_updated": "2026-02-05T22:30:00Z"
}
```

**Wristband Ranges:**
- Pre-registered: #1-249
- Walk-ins: #250+ (separate counter)

**State Persistence:**
- Saved after every operation
- Enables crash recovery
- Tracks all previous matches to prevent duplicates

### 4. CLI Menu System

**Main Menu:**
```
=== BRIDGE PUB MATCHER ===
Participants: 195 | Checked in: 0 | Gender: 0M / 0F / 0NB
Batches: 0 | Unsent: 0

1. Check in participant (pre-registered)
2. Check out participant
3. View current status
4. Generate new matches
5. Send matches via Twilio
6. Export results
7. Reset system (USE WITH CAUTION)
8. Reload participant data
9. View match history for person
10. View all matches for batch
11. Check in walk-in (starts at wristband #250)
12. Undo last check-in/check-out
13. Exit

Choose option:
```

**Key Options:**

**Option 1: Check In (Pre-Registered)**
- Search by name/email/phone
- Assigns next wristband from #1-249 range
- Reuses existing wristband if re-checking in

**Option 11: Check In Walk-In**
- For people not in pre-registration
- Assigns wristband from #250+ range
- Must reload data (Option 8) after merging CSV

**Option 12: Undo**
- Reverts last check-in or check-out operation
- Frees wristband number if check-in
- Re-checks person in if check-out

**Option 7: Reset System**
- Clears all check-ins, matches, wristband numbers
- **Also resets special request state** (batches_together, matched flags)
- Keeps participant data
- Requires typing "RESET" to confirm

**Option 8: Reload Data**
- Reloads current_bridge_pub_complete.csv
- Preserves all check-ins and matches
- Adds new participants

---

## Matching Algorithm

### Phase 0: Special Requests

**Highest priority matches - happen before all filters**

1. Load special_requests from state
2. For each request where matched = false:
   - Find requester by phone
   - Find requested person by phone OR exact name
   - If both checked in: increment batches_together counter
   - If batches_together reaches 2: **AUTO-MATCH**
3. Deduplicates mutual requests (A→B + B→A = 1 match)
4. Marks requests as matched
5. Returns special matches

### Phase 1 & 2: Prioritized Romantic Matching

**All romantic pairs sorted by friend match history**

**Priority System:**
- **Priority 2 (Highest):** Both people had friend matches before
- **Priority 1 (Medium):** One person had a friend match before
- **Priority 0 (Lowest):** Neither had friend matches before

**Algorithm:**
1. Build all possible romantic pairs (hard filters apply)
2. Assign priority based on friend match history
3. Sort by priority (descending), then compatibility score (descending)
4. Match greedily from highest to lowest priority
5. This ensures people with friend matches get first pick

**Hard Filters:**
- Both checked in
- Phone numbers available
- Not previously matched together
- Gender preference compatible (bidirectional)
- Grade compatible (no Freshman-Senior, unless grade missing)

**Compatibility Scoring (0-130 points):**
- Grade proximity: 0-20 points
- School match: 10 points
- Ideal Friday night: 15 points
- Emotion vs Logic: 15 points
- Plan vs Spontaneous: 15 points
- Fitness importance: 0-20 points
- Important value: 20 points
- Reading habit: 10 points

### Phase 3: Friend Matching

**Only for people who never had a friend match**

**Hard Constraint Requirement:**
- Only matches people blocked by gender preference OR grade incompatibility
- NOT for low compatibility scores

**Friend Match Limit:** 1 per person lifetime
- After friend match, person gets priority for romantic matches (Phase 1)
- Cannot get a second friend match

**How It Works:**
1. Filter eligible: unmatched + never had friend match
2. Build pairs where blocked by gender OR grade
3. Sort by compatibility score
4. Match greedily
5. If odd number: create one group of 3

**Groups of 3:**
- Last pair + leftover person
- All 3 receive messages with both other wristband numbers
- All 3 count as having had friend match

---

## Twilio Integration

### Message Formats

**Romantic Match:**
```
"Your Bridge match is #42!"
```

**Friend Match (pair of 2):**
```
"We didn't find a romantic interest for you this round, but you'd make great friends with #42! You'll be prioritized for a romantic match next round."
```

**Friend Match (group of 3):**
```
"We didn't find a romantic interest for you this round, but you'd make great friends with #42 and #87! You'll be prioritized for a romantic match next round."
```

**Special Request Match:**
```
"Your Bridge match is #42!"
(Same as romantic - sent as type='special_request')
```

### Key Features

- **Anonymous:** Only wristband numbers, no names
- **Priority messaging:** Friend matches inform people they'll be prioritized
- **Failed send logging:** Writes to failed_sends.txt
- **Safety lockout:** Currently enabled - MUST REMOVE BEFORE FRIDAY

### Environment Variables

```bash
# .env
TWILIO_ACCOUNT_SID=your_sid_here
TWILIO_AUTH_TOKEN=your_token_here
TWILIO_PHONE_NUMBER=+15551234567
```

---

## Error Handling & Edge Cases

### Crash Recovery
- Restart script: `ruby bridge_matcher.rb`
- State automatically loaded from bridge_state.json
- Continue from where you left off

### Validation Checks

**Before generating matches:**
- At least 2 people checked in
- Compatible pairs exist

**Before sending messages:**
- Unsent matches exist
- Twilio credentials configured
- Confirmation required

### Edge Cases Handled

1. **Odd number of participants:** Some unmatched
2. **Gender imbalance (83M/59F):** Friend matching for extras
3. **No compatible romantic matches:** Friend matching fallback
4. **Duplicate check-in:** Shows existing wristband
5. **Check-out then re-check-in:** Reuses same wristband
6. **9-digit phone:** Validated in new registrations (Ian needs manual fix)
7. **Missing grade:** Allowed, skips grade filter for these people
8. **Special request mutual:** Deduplicates A→B and B→A
9. **Friend match limit:** Enforced at 1 per person
10. **Groups of 3:** All 3 count as having had friend match

---

## Event Night Workflow

### Setup (Before 9:00 PM)

1. **Remove Twilio Safety Lockout**
   ```bash
   # Edit bridge_matcher.rb
   # Search for "SAFETY LOCKOUT" (line ~1274)
   # Delete or comment out that entire section
   ```

2. **Fix Ian's Phone**
   ```bash
   # Edit current_bridge_pub_complete.csv
   # Find Ian (row 172)
   # Change phone from 902184475 to correct 10-digit number
   ```

3. **Start Script**
   ```bash
   ruby bridge_matcher.rb
   ```

4. **Verify:**
   - Participants loaded: 195
   - Special requests loaded: 33
   - Wristbands ready: #1-249 for pre-reg, #250+ for walk-ins

### During Event (10:00 PM - 1:00 AM)

**Check-Ins (Ongoing):**
- Option 1: Check in pre-registered participants
- Hand out numbered wristbands
- Option 11: Check in walk-ins (after merging CSV)

**Match Generation (3-4 times during night):**

**Batch 1:**
1. Option 4: Generate matches
2. Review output:
   - Special requests: Should see 6 (if all checked in for 2nd time)
   - Romantic matches with priority breakdown
   - Friend matches (hard constraints only)
3. Confirm matches
4. Option 5: Send via Twilio
5. Watch the magic happen!

**Batch 2+:**
1. More people checked in
2. Option 4: Generate matches
3. People with friend matches get priority for romantic
4. Special requests continue to check (batches_together)
5. Send matches
6. Repeat as desired!

**Walk-In Registration (As Needed):**
1. Export new Typeform responses
2. `ruby add_new_registrations.rb new_export.csv`
3. Script validates phones and merges
4. Option 8: Reload data
5. Option 11: Check in walk-ins
6. Continue matching!

**Post-Event:**
- Option 6: Export all results
- Backup bridge_state.json
- Delete PII data

---

## Troubleshooting

**Script crashes:**
- Restart: `ruby bridge_matcher.rb`
- State restored automatically
- Continue from last checkpoint

**Twilio not sending:**
- Check if safety lockout still enabled (line ~1274)
- Verify .env credentials
- Check Twilio account balance
- Check failed_sends.txt for errors

**Special requests not matching:**
- Run `ruby validate_special_requests.rb` to see status
- Check if both people are in system (requested person may not be registered)
- Check if batches_together = 2 (need 2 batches where both checked in)
- Run `ruby debug_special_requests.rb` for detailed info

**Friend matches repeating:**
- Should be fixed - friend matches now marked with type='friend'
- has_friend_match?() checks both 'friend' and 'friend_group_of_3'
- If still happening, check COMPREHENSIVE_AUDIT.md

**Wrong wristband assigned:**
- Option 12: Undo last operation
- Re-check in with correct process

**Phone validation failing:**
- add_new_registrations.rb requires exactly 10 digits
- If valid phone rejected, check for non-numeric characters
- Manual edit in CSV if needed

---

## System Status: 95% Ready

### ✓ Completed Features

- ✅ Special request matching (phone OR exact name)
- ✅ Friend match prioritization for romantic matches
- ✅ Friend match limit (1 per person)
- ✅ Groups of 3 support
- ✅ Walk-in system with separate wristband range
- ✅ Phone validation (10 digits required)
- ✅ Undo functionality
- ✅ Reset system (includes special requests)
- ✅ Mutual request deduplication
- ✅ Anonymous messaging (wristband numbers only)
- ✅ Priority messaging for friend matches
- ✅ State persistence and crash recovery

### ⚠️ Must Fix Before Friday

1. **Remove Twilio safety lockout** (5 minutes)
   - Line ~1274 in bridge_matcher.rb
   - Search for "SAFETY LOCKOUT"

2. **Fix Ian's phone** (2 minutes)
   - Row 172 in current_bridge_pub_complete.csv
   - Current: 902184475 (9 digits)
   - Need: correct 10-digit number

### Known Limitations

- No manual match editing (must regenerate or use Twilio dashboard)
- No undo for sent messages
- People can't be matched with same person twice
- No photo integration
- CLI only (no web interface)

---

## Testing Checklist

Before Friday:

- [ ] Remove Twilio safety lockout
- [ ] Fix Ian's phone number
- [ ] Restart script to load changes
- [ ] Generate batch 1 with test data
  - [ ] Verify special requests work
  - [ ] Verify friend matches limited to 1
  - [ ] Verify romantic prioritization
- [ ] Generate batch 2
  - [ ] Verify special requests trigger on 2nd batch
  - [ ] Verify friend match people get romantic priority
- [ ] Send test messages to yourself
  - [ ] Verify romantic message format
  - [ ] Verify friend message format
- [ ] Test walk-in workflow
- [ ] Test undo functionality
- [ ] Test reset system
- [ ] Backup bridge_state.json

---

## Quick Reference

**Key Files:**
- `current_bridge_pub_complete.csv` - Master participant list
- `special_requests.json` - Special request definitions
- `bridge_state.json` - Runtime state (auto-generated)
- `bridge_matcher.rb` - Main script

**Key Commands:**
```bash
# Start system
ruby bridge_matcher.rb

# Merge walk-in registrations
ruby add_new_registrations.rb new_export.csv

# Validate special requests
ruby validate_special_requests.rb

# Debug special requests
ruby debug_special_requests.rb
```

**Wristband Ranges:**
- Pre-reg: #1-249
- Walk-ins: #250+

**Match Types:**
- `special_request` - Phase 0 (requested pairs)
- `romantic` - Phase 1&2 (compatibility-based)
- `friend` - Phase 3 (hard constraint failures)
- `friend_group_of_3` - Phase 3 (odd number handling)

**Priority Levels:**
- Priority 2: Both had friend matches
- Priority 1: One had friend match
- Priority 0: Neither had friend match

---

**Ready for Friday! 🎉**

See COMPREHENSIVE_AUDIT.md for detailed system analysis.
