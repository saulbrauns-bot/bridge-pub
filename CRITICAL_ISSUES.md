# Critical Issues & Solutions for Friday Night

## 1. TWILIO FAILURES (HIGH PRIORITY)

### Current Implementation:
- 0.1s delay between messages
- Basic error catching
- No retry logic

### Potential Issues:
- ❌ Twilio rate limits (max 10 msg/sec on trial accounts)
- ❌ Account balance runs out mid-send
- ❌ Network issues cause failures
- ❌ Invalid phone numbers crash the send

### Solutions Implemented:
✅ Error catching per message
✅ Failed message count
✅ Batch marked as sent even if some fail

### What Could Go Wrong:
- Some people don't get texts
- Need manual resend

### Manual Fix During Event:
- Check Twilio dashboard for failed numbers
- Manually text them or tell them their match

---

## 2. GENDER IMBALANCE (MEDIUM PRIORITY)

### Scenario:
- 100 males checked in
- 30 females checked in
- Max 30 romantic matches possible
- 70 males will get friend matches or nothing

### Current Behavior:
✅ Algorithm handles this gracefully
✅ Friend matching catches overflow
✅ Some people may get no match in a batch

### Not a Real Problem:
- System already handles this
- Friend matches use same scoring
- Just explain to attendees some batches may not have matches for everyone

---

## 3. TECHNICAL FAILURES (HIGH PRIORITY)

### What If Script Crashes?
✅ **SOLUTION: State is auto-saved after every operation**
- Just restart: `ruby bridge_matcher.rb`
- All check-ins preserved
- All matches preserved
- Can continue from where you left off

### What If Computer Dies?
❌ **NO BACKUP**: State only on local machine
- ⚠️ RECOMMENDATION: Copy `bridge_state.json` to Dropbox/Google Drive every hour

### What If Internet Goes Down?
❌ **CAN'T SEND MESSAGES**: Twilio needs internet
- ✅ Can still check people in
- ✅ Can still generate matches
- ❌ Can't send via Twilio
- **BACKUP PLAN**: Export matches to CSV, manually tell people

---

## 4. OPERATIONAL ISSUES (MEDIUM PRIORITY)

### Fast Check-In Queue
**Problem:** 50 people arrive at once, you need to check them in quickly

**Current:** Type name for each person (slow)

**Solution Added Below:** Quick check-in by list number

### Lost Wristband
**Problem:** Someone loses their wristband, doesn't know their number

**Solution:** Search by name in check-out, shows their wristband number

### Wrong Match Sent
**Problem:** Match sent but it's wrong/bad pairing

**Current:** Can't unsend texts
**Solution:** Generate new batch, send correction manually via Twilio dashboard

---

## 5. DATA ISSUES (LOW PRIORITY)

### Wrong Phone Number
**Scenario:** Person signed up with typo in phone
**Solution:**
1. They won't get text
2. Check them in anyway
3. Manually tell them their match number

### Duplicate Submissions
✅ **ALREADY HANDLED**: merge_data.rb removes duplicates (keeps most recent)

### Person No-Show
**Solution:** Just don't check them in. They won't be in matching pool.

---

## 6. MISSING FEATURES (NICE TO HAVE)

### High Priority for Tonight:
1. ✅ **View individual person**: Check if someone has been matched
2. ✅ **Gender balance stats**: Quick view of male/female ratio
3. ⚠️ **Export failed sends**: List of phone numbers that didn't receive texts
4. ⚠️ **Manual match**: Force two people to match

### Medium Priority:
5. **Undo last check-in/out**: Accidentally checked wrong person
6. **Search checked-in people**: "Show all females" or "Show unmatched"
7. **Match quality report**: Show score distribution
8. **Bulk check-out**: End of night, check everyone out at once

### Low Priority (Skip for now):
- Web interface
- Multi-operator support
- Real-time updates
- Photo integration

---

## EMERGENCY PROCEDURES

### If Twilio Stops Working:
1. **Option 6**: Export results to CSV
2. Open CSV, manually call out match numbers
3. Or use Twilio dashboard to send bulk SMS

### If Script Crashes During Send:
1. Restart script
2. **Option 3**: View status - see which batch was being sent
3. Check `batch['sent_at']` in bridge_state.json
4. If null, batch wasn't marked sent - some people didn't get texts
5. Use Twilio dashboard to see who received messages
6. Manually notify people who didn't get texts

### If Computer Dies:
1. ⚠️ **CRITICAL**: All data in `bridge_state.json` is LOST
2. **PREVENTION**: Every 30 minutes, copy these files to USB/cloud:
   - `bridge_state.json`
   - `merged_participants.csv`
3. If you have backup, copy back and restart

### If You Need to Stop Everything:
1. **Option 7**: Reset system
2. Type "RESET" to confirm
3. Starts fresh (but keeps participant data)

---

## PRE-EVENT CHECKLIST

□ Test Twilio by sending yourself a message
□ Check Twilio account balance ($10+ recommended)
□ Backup bridge_state.json to cloud before event
□ Print wristband numbers 1-150
□ Have phone charger plugged in
□ Test internet connection at venue
□ Know the WiFi password
□ Have emergency phone numbers ready
□ Print this emergency procedures doc

---

## QUICK REFERENCE

**Check someone's status:**
- Start script → Option 3 → Look for their name

**Resend failed messages:**
- Go to Twilio dashboard → Messaging → Send new message

**Export all matches:**
- Option 6 → Opens bridge_matches_export.csv

**Backup state file:**
```bash
cp bridge_state.json bridge_state_backup_$(date +%H%M).json
```

**Check Twilio balance:**
- https://console.twilio.com/ → Balance in top right
