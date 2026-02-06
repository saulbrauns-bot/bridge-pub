#!/bin/bash
# Auto-update GitHub Pages with latest matches

# Check if index.html or version.json has changes
if git diff --quiet index.html version.json 2>/dev/null; then
  echo "No changes to publish"
  exit 0
fi

# Add and commit index.html and version.json
git add index.html version.json
git commit -m "Auto-update matches webpage - $(date '+%Y-%m-%d %H:%M:%S')" > /dev/null 2>&1

# Push to GitHub
if git push origin main > /dev/null 2>&1; then
  echo "✓ GitHub Pages updated successfully"
  echo "  Live at: https://saulbrauns-bot.github.io/bridge-pub/"
else
  echo "⚠️  Failed to push to GitHub (check network connection)"
  exit 1
fi
