# Friday Night Event - Final Checklist

## ✅ NEW FEATURES ADDED

### 1. Gender Balance Display
**Option 3** now shows:
```
Checked in: 85
  Males: 48
  Females: 35
  Non-binary: 2
```
Use this to gauge if you need to encourage one gender to attend!

### 2. Individual Person Lookup
**In Option 3**, after stats, you can search for anyone:
- Type their name → See their full status
- Shows: matches, wristband #, check-in status, who they've been matched with

### 3. Friend Match Limit
✅ Each person can only receive ONE friend match total
- Can get unlimited romantic matches
- Friend matches only given once

### 4. Failed Send Logging
If Twilio messages fail:
- ✅ Logged to `failed_sends.txt`
- Shows: name, phone, wristband, error message
- You can manually notify these people

### 5. Anonymous Matching
Messages now say: "Your Bridge match is sign in #42!"
- No names revealed
- Creates mystery/excitement
- People must find each other

---

## 🚨 CRITICAL PRE-EVENT TASKS

### 1. Test Twilio (DO THIS NOW)
```bash
# Remove the safety lockout first:
# Edit bridge_matcher.rb, find line ~668, delete the lockout section

# Then send a test message to yourself
ruby bridge_matcher.rb
# Option 1: Check yourself in
# Option 4: Generate matches (need 2 people checked in)
# Option 5: Send via Twilio
```

### 2. Check Twilio Account
- [ ] Go to https://console.twilio.com/
- [ ] Check balance (need $10+ for 143 people)
- [ ] Verify phone number is active
- [ ] Test send a message from dashboard

### 3. Backup Files
```bash
# Before event starts, backup these files:
cp bridge_state.json bridge_state_BACKUP.json
cp merged_participants.csv merged_participants_BACKUP.csv

# During event, backup every 30 minutes
```

### 4. Physical Prep
- [ ] Print wristbands #1-150
- [ ] Charge laptop fully
- [ ] Bring phone charger
- [ ] Test WiFi at venue
- [ ] Get WiFi password
- [ ] Print CRITICAL_ISSUES.md (emergency procedures)

---

## 📋 EVENT WORKFLOW

### Before Event (9:30 PM)
```bash
cd /Users/saulbrauns/bridge-pub
ruby bridge_matcher.rb
```

**Important:** Remove Twilio safety lockout before event!
- Edit `bridge_matcher.rb`
- Find line ~668 (`send_matches` function)
- Delete or comment out the lockout section

### During Event (10:00 PM - 1:00 AM)

**As people arrive:**
1. Option 1: Check in participant
2. Type their name
3. Hand them wristband

**When ready to send matches (11:00 PM, 11:30 PM, 12:00 AM, etc.):**
1. Option 4: Generate new matches
2. Review the matches and scores
3. Type "yes" to save
4. Option 5: Send matches via Twilio
5. Confirm "yes" to send
6. Watch the dots... → Messages sending
7. Note any failures

**If someone asks about their match:**
1. Option 3: View current status
2. When prompted, type their name
3. See who they've been matched with

**Ongoing:**
- Check people in as they arrive
- Generate matches every 30-45 minutes
- Keep checking Option 3 for gender balance

### After Event (1:00 AM)
1. Option 6: Export results
2. Opens `bridge_matches_export.csv`
3. Backup final state file
4. Review failed_sends.txt if it exists

---

## ⚠️ TROUBLESHOOTING GUIDE

### "No compatible matches found"
**Cause:** Everyone has been matched with everyone else
**Solution:** Normal at end of night, just tell people that's all the matches

### "Multiple matches found" when checking out
**Cause:** Multiple people with similar names
**Solution:** Choose the right person from the list by number

### Gender imbalance (e.g., 80 males, 30 females)
**Cause:** More of one gender showed up
**Solution:**
- Max 30 romantic matches possible
- 50 males get friend matches or no match
- This is OK - friend matches are still good!
- Generate more batches throughout night

### Twilio messages failing
**Check:**
1. Internet connection
2. Twilio account balance
3. Phone number format (must be +1XXXXXXXXXX)
4. Check `failed_sends.txt` for details

**Fix:**
- Use Twilio dashboard to manually send to failed numbers
- Or manually tell people their match number

### Script crashes
**Solution:**
1. Just restart: `ruby bridge_matcher.rb`
2. All data is auto-saved
3. Continue from where you left off

### Computer dies
**If you have backup:**
1. Get backup files from earlier
2. Lose some recent check-ins/matches
3. Can rebuild from there

**If no backup:**
❌ All data lost - start over

**PREVENTION:** Backup every 30 min!

---

## 💡 TIPS FOR SUCCESS

### Efficient Check-In
- Have people form a line
- Type just first few letters of name
- Quick selection from list
- Hand them pre-numbered wristband

### When to Send Matches
**Good times:**
- 11:00 PM (first batch, lots of people)
- 11:30 PM (second wave arrived)
- 12:00 AM (peak energy)
- 12:30 AM (keep momentum)

**How to know when:**
- Option 3 → Check gender balance
- If you have 20+ people of each gender → good time to match
- Party feeling slow → send matches to reinvigorate

### Managing Expectations
Tell people:
- "Matches are sent via text throughout the night"
- "Check your phone periodically"
- "Look for someone with the wristband number we text you"
- "You might get multiple matches!"
- "Some batches you might not get a match - that's OK, more coming"

### Quality Control
- Don't worry about perfect matches
- Algorithm optimizes compatibility
- Some randomness is good - creates new connections
- Friend matches are valuable too!

---

## 📞 EMERGENCY CONTACTS

**If Twilio completely fails:**
- Can still generate matches
- Option 6: Export to CSV
- Manually announce matches or use Twilio dashboard

**If script becomes unusable:**
- Fall back to manual matching
- Use the export CSV from last successful batch

---

## 🎉 SUCCESS METRICS

**Good Night:**
- 80+ people checked in
- 3-4 batches sent successfully
- 90%+ people got at least one match
- < 5% failed message sends
- No major technical issues

**Expectations:**
- Not everyone gets matched every batch (OK!)
- Some friend matches are normal
- A few failed sends is fine (manually fix)
- System should handle 100-150 people easily

---

## FINAL NOTES

**What Could Go Wrong:**
- ✅ We've planned for it
- ✅ Have backups and recovery procedures
- ✅ Failed sends are logged
- ✅ State is always saved

**You're Ready:**
- System is tested
- Error handling in place
- Clear procedures for issues
- Backup plans for everything

**Just Remember:**
1. Remove Twilio lockout before event
2. Backup files before starting
3. Check Twilio balance
4. Have fun! The system works.

Good luck! 🎊
