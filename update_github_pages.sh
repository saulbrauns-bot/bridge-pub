#!/bin/bash
# Auto-update GitHub Pages with latest matches

LOCKFILE=".last_push_timestamp"
COOLDOWN_SECONDS=30

# Check if index.html has changes
if git diff --quiet index.html 2>/dev/null; then
  echo "No changes to publish"
  exit 0
fi

# Check cooldown period to prevent rapid deployments
if [ -f "$LOCKFILE" ]; then
  LAST_PUSH=$(cat "$LOCKFILE")
  CURRENT_TIME=$(date +%s)
  TIME_DIFF=$((CURRENT_TIME - LAST_PUSH))

  if [ $TIME_DIFF -lt $COOLDOWN_SECONDS ]; then
    WAIT_TIME=$((COOLDOWN_SECONDS - TIME_DIFF))
    echo "⏳ Cooldown active - waiting ${WAIT_TIME}s to avoid deployment conflicts"
    sleep $WAIT_TIME
  fi
fi

# Add and commit index.html
git add index.html
git commit -m "Auto-update matches webpage - $(date '+%Y-%m-%d %H:%M:%S')" > /dev/null 2>&1

# Push to GitHub
if git push origin main > /dev/null 2>&1; then
  # Record push timestamp
  date +%s > "$LOCKFILE"
  echo "✓ GitHub Pages updated successfully"
  echo "  Live at: https://saulbrauns-bot.github.io/bridge-pub/"
else
  echo "⚠️  Failed to push to GitHub (check network connection)"
  exit 1
fi
