#!/usr/bin/env ruby
require 'json'

# Load state
unless File.exist?('bridge_state.json')
  # No state file yet - create empty page
  empty_html = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Bridge Pub Matches</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          color: white;
          text-align: center;
        }
        h1 { font-size: 3em; margin-bottom: 20px; }
        p { font-size: 1.2em; opacity: 0.8; }
      </style>
    </head>
    <body>
      <div>
        <h1>💜 Bridge Pub Matches</h1>
        <p>No matches generated yet</p>
      </div>
    </body>
    </html>
  HTML
  File.write('matches_display.html', empty_html)
  File.write('index.html', empty_html)
  puts "✓ Generated empty matches page (no state file yet)"
  exit
end

state = JSON.parse(File.read('bridge_state.json'))

# Check if any batches exist
if state['match_batches'].nil? || state['match_batches'].empty?
  # No matches yet - create empty page
  empty_html = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Bridge Pub Matches</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          color: white;
          text-align: center;
        }
        h1 { font-size: 3em; margin-bottom: 20px; }
        p { font-size: 1.2em; opacity: 0.8; }
      </style>
    </head>
    <body>
      <div>
        <h1>💜 Bridge Pub Matches</h1>
        <p>No matches generated yet</p>
      </div>
    </body>
    </html>
  HTML
  File.write('matches_display.html', empty_html)
  File.write('index.html', empty_html)
  puts "✓ Generated empty matches page (no batches yet)"
  exit
end

# Get the LAST (most recent) batch
batch = state['match_batches'].last

html = <<~HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bridge Pub Matches - Batch #{batch['batch_number']}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      padding: 20px;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
    }
    .header {
      text-align: center;
      color: white;
      margin-bottom: 40px;
    }
    .header h1 {
      font-size: 3em;
      margin-bottom: 10px;
      text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
    }
    .header p {
      font-size: 1.2em;
      opacity: 0.9;
    }
    .stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
      margin-bottom: 40px;
    }
    .stat-card {
      background: white;
      padding: 20px;
      border-radius: 12px;
      text-align: center;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    .stat-card h3 {
      color: #667eea;
      font-size: 2em;
      margin-bottom: 5px;
    }
    .stat-card p {
      color: #666;
      font-size: 0.9em;
    }
    .matches-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 20px;
    }
    .match-card {
      background: white;
      padding: 25px;
      border-radius: 12px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
      transition: transform 0.2s, box-shadow 0.2s;
    }
    .match-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 12px rgba(0,0,0,0.2);
    }
    .match-header {
      display: flex;
      justify-content: center;
      align-items: center;
      margin-bottom: 15px;
      padding-bottom: 15px;
      border-bottom: 2px solid #f0f0f0;
    }
    .match-type {
      padding: 5px 12px;
      border-radius: 20px;
      font-size: 0.75em;
      font-weight: 600;
      text-transform: uppercase;
    }
    .type-romantic {
      background: #ffeef0;
      color: #e91e63;
    }
    .type-friend {
      background: #e3f2fd;
      color: #2196f3;
    }
    .type-special_request {
      background: #fff3e0;
      color: #ff9800;
    }
    .match-person {
      margin: 10px 0;
      padding: 15px;
      background: #f8f9fa;
      border-radius: 8px;
      text-align: center;
    }
    .wristband {
      display: inline-block;
      background: #667eea;
      color: white;
      padding: 12px 24px;
      border-radius: 25px;
      font-weight: bold;
      font-size: 1.8em;
    }
    @media (max-width: 768px) {
      .header h1 { font-size: 2em; }
      .matches-grid { grid-template-columns: 1fr; }
    }
  </style>
  <script>
    // Auto-refresh when new matches are posted
    let currentBatch = #{batch['batch_number']};

    async function checkForUpdates() {
      try {
        const response = await fetch('version.json?t=' + Date.now());
        const data = await response.json();

        if (data.batch_number > currentBatch) {
          console.log('New matches detected! Refreshing...');
          location.reload();
        }
      } catch (error) {
        console.log('Check failed, will retry');
      }
    }

    // Check every 15 seconds
    setInterval(checkForUpdates, 15000);
    console.log('Auto-refresh enabled - checking for new matches every 15 seconds');
  </script>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>💜 Bridge Pub Matches</h1>
    </div>

    <div class="stats">
      <div class="stat-card">
        <h3>#{batch['matches'].size}</h3>
        <p>Total Matches</p>
      </div>
      <div class="stat-card">
        <h3>#{batch['matches'].count { |m| m['type'] == 'romantic' || m['type'] == 'special_request' }}</h3>
        <p>Romantic Matches</p>
      </div>
      <div class="stat-card">
        <h3>#{batch['matches'].count { |m| m['type'] == 'friend' || m['type'] == 'friend_group_of_3' }}</h3>
        <p>Friend Matches</p>
      </div>
    </div>

    <div class="matches-grid">
HTML

# Sort matches by lowest wristband number
sorted_matches = batch['matches'].sort_by do |match|
  wristbands = [match['person_a_wristband'], match['person_b_wristband']]
  wristbands << match['person_c_wristband'] if match['person_c_wristband']
  wristbands.min
end

sorted_matches.each_with_index do |match, i|
  # Display special_request as romantic (silent from frontend perspective)
  display_type = match['type'] == 'special_request' ? 'romantic' : match['type']
  type_class = "type-#{display_type || 'romantic'}"
  type_label = case display_type
               when 'friend' then '🤝 Friend'
               when 'friend_group_of_3' then '👥 Group of 3'
               else '💕 Romantic'
               end

  if match['person_c_email']
    # Group of 3
    html += <<~MATCH
    <div class="match-card">
      <div class="match-header">
        <span class="match-type #{type_class}">#{type_label}</span>
      </div>
      <div class="match-person">
        <span class="wristband">##{match['person_a_wristband']}</span>
      </div>
      <div class="match-person">
        <span class="wristband">##{match['person_b_wristband']}</span>
      </div>
      <div class="match-person">
        <span class="wristband">##{match['person_c_wristband']}</span>
      </div>
    </div>
    MATCH
  else
    # Regular pair
    html += <<~MATCH
    <div class="match-card">
      <div class="match-header">
        <span class="match-type #{type_class}">#{type_label}</span>
      </div>
      <div class="match-person">
        <span class="wristband">##{match['person_a_wristband']}</span>
      </div>
      <div class="match-person">
        <span class="wristband">##{match['person_b_wristband']}</span>
      </div>
    </div>
    MATCH
  end
end

html += <<~HTML
    </div>
  </div>
</body>
</html>
HTML

File.write('matches_display.html', html)
File.write('index.html', html)

# Generate version file for auto-refresh detection
version_data = {
  'batch_number' => batch['batch_number'],
  'timestamp' => batch['generated_at'],
  'match_count' => batch['matches'].size
}
File.write('version.json', JSON.generate(version_data))

puts "✓ Generated matches_display.html and index.html"
puts "  Batch #{batch['batch_number']} - #{batch['matches'].size} matches (latest)"

# Auto-push to GitHub Pages
puts "\n📤 Pushing to GitHub Pages..."
system('./update_github_pages.sh')
