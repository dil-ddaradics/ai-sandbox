#!/usr/bin/env bash
# simulate-url-corruption.sh - Simulates corruption of the credential URL file
set -euo pipefail

URL_FILE="$HOME/.cc/awsvault_url"

# Check if URL file exists
if [[ ! -f "$URL_FILE" ]]; then
  echo "❌ Error: URL file not found at $URL_FILE"
  echo "Please run cc-awsvault <profile> first to create the URL file"
  exit 1
fi

# Create backup of original URL file
cp "$URL_FILE" "${URL_FILE}.bak"
echo "✅ Created backup of original URL file: ${URL_FILE}.bak"

# Ask what type of corruption to simulate
echo "Choose corruption type:"
echo "1) Empty file"
echo "2) Invalid URL format"
echo "3) Valid format but wrong host/port"
echo "4) Random garbage data"
read -p "Enter choice (1-4): " corruption_choice

case $corruption_choice in
  1)
    # Empty file
    echo -n "" > "$URL_FILE"
    echo "✅ Simulated corruption: Empty file"
    ;;
  2)
    # Invalid URL format
    echo "not-a-url" > "$URL_FILE"
    echo "✅ Simulated corruption: Invalid URL format"
    ;;
  3)
    # Valid format but wrong host/port
    echo "http://host.docker.internal:12345" > "$URL_FILE"
    echo "✅ Simulated corruption: Valid format but wrong host/port"
    ;;
  4)
    # Random garbage data
    head -c 100 /dev/urandom | base64 > "$URL_FILE"
    echo "✅ Simulated corruption: Random garbage data"
    ;;
  *)
    echo "❌ Invalid choice, not corrupting the file"
    mv "${URL_FILE}.bak" "$URL_FILE"
    exit 1
    ;;
esac

echo
echo "🔍 Testing container response to corrupted URL file..."
echo "Run the following to see how the container handles the corruption:"
echo "  cc-up      # Should show warnings about URL"
echo "  cc-chat    # Should show connectivity errors"
echo
echo "To restore the original URL file:"
echo "  mv ${URL_FILE}.bak $URL_FILE"