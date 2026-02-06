#!/usr/bin/env ruby
require 'json'
require 'time'

# Generate a simple HTML page showing current matches
def generate_matches_webpage(state, batch_number)
  batch = state['match_batches'].find { |b| b['batch_number'] == batch_number }

  return unless batch

  matches = batch['matches']
  sent_at = batch['sent_at'] ? Time.parse(batch['sent_at']).localtime.strftime('%I:%M %p') : 'Not sent yet'

  html = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Bridge Pub Matches - Batch #{batch_number}</title>
      <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }

        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
          padding: 20px;
        }

        .container {
          max-width: 600px;
          margin: 0 auto;
        }

        .header {
          background: white;
          border-radius: 15px;
          padding: 25px;
          margin-bottom: 20px;
          box-shadow: 0 10px 30px rgba(0,0,0,0.2);
          text-align: center;
        }

        .header h1 {
          color: #667eea;
          font-size: 28px;
          margin-bottom: 10px;
        }

        .header .batch-info {
          color: #666;
          font-size: 14px;
        }

        .match-card {
          background: white;
          border-radius: 15px;
          padding: 20px;
          margin-bottom: 15px;
          box-shadow: 0 5px 15px rgba(0,0,0,0.1);
          display: flex;
          align-items: center;
          justify-content: space-between;
        }

        .wristband {
          flex: 1;
          text-align: center;
          font-size: 32px;
          font-weight: bold;
          color: #667eea;
        }

        .wristband-label {
          font-size: 12px;
          color: #999;
          text-transform: uppercase;
          letter-spacing: 1px;
          margin-bottom: 5px;
        }

        .match-arrow {
          font-size: 24px;
          color: #764ba2;
          padding: 0 15px;
        }

        .match-type {
          font-size: 11px;
          color: white;
          background: #764ba2;
          padding: 4px 10px;
          border-radius: 10px;
          margin-top: 8px;
          display: inline-block;
        }

        .match-type.friend {
          background: #48bb78;
        }

        .match-type.special {
          background: #f6ad55;
        }

        .group-of-3 {
          flex-direction: column;
        }

        .group-of-3 .wristband {
          font-size: 24px;
          margin: 5px 0;
        }

        .footer {
          text-align: center;
          color: white;
          margin-top: 30px;
          font-size: 12px;
          opacity: 0.8;
        }

        .refresh-note {
          background: rgba(255,255,255,0.2);
          color: white;
          padding: 10px;
          border-radius: 10px;
          text-align: center;
          margin-bottom: 20px;
          font-size: 14px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🌉 Bridge Pub Matches</h1>
          <div class="batch-info">
            Batch ##{batch_number} • Sent at #{sent_at}<br>
            #{matches.size} matches
          </div>
        </div>

        <div class="refresh-note">
          📱 Refresh this page to see new matches
        </div>
  HTML

  # Add each match
  matches.each_with_index do |match, i|
    if match['type'] == 'friend_group_of_3'
      # Group of 3
      html += <<~HTML
        <div class="match-card group-of-3">
          <div class="wristband-label">Friend Group</div>
          <div class="wristband">##{match['person_a_wristband']}</div>
          <div class="match-arrow">↔</div>
          <div class="wristband">##{match['person_b_wristband']}</div>
          <div class="match-arrow">↔</div>
          <div class="wristband">##{match['person_c_wristband']}</div>
          <div class="match-type friend">Friend Group</div>
        </div>
      HTML
    else
      # Regular pair
      type_label = match['type'] == 'romantic' ? 'Romantic' : 'Friend'
      type_class = match['type'] == 'romantic' ? '' : 'friend'
      type_class = 'special' if match['type'] == 'special_request'

      html += <<~HTML
        <div class="match-card">
          <div>
            <div class="wristband-label">Wristband</div>
            <div class="wristband">##{match['person_a_wristband']}</div>
          </div>
          <div class="match-arrow">↔</div>
          <div>
            <div class="wristband-label">Wristband</div>
            <div class="wristband">##{match['person_b_wristband']}</div>
          </div>
        </div>
      HTML
    end
  end

  html += <<~HTML
        <div class="footer">
          Last updated: #{Time.now.strftime('%I:%M:%S %p')}<br>
          Bridge Pub Matching System
        </div>
      </div>
    </body>
    </html>
  HTML

  # Write to file
  File.write('matches_display.html', html)

  puts "  ✓ Webpage updated: matches_display.html"
end

# Can be called standalone for testing
if __FILE__ == $0
  require 'json'

  if File.exist?('bridge_state.json')
    state = JSON.parse(File.read('bridge_state.json'))

    # Find the most recent batch
    if state['match_batches'].any?
      latest_batch = state['match_batches'].last
      generate_matches_webpage(state, latest_batch['batch_number'])
      puts "\n✓ Generated webpage for Batch ##{latest_batch['batch_number']}"
      puts "  Open matches_display.html in your browser"
    else
      puts "No matches found yet"
    end
  else
    puts "bridge_state.json not found"
  end
end
