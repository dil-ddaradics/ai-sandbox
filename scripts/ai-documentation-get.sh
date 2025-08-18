#!/usr/bin/env bash
# ai-documentation-get.sh - Extract and format AI Sandbox documentation
set -euo pipefail
source "$(dirname "$0")/_common.sh"

# Parse arguments
JSON_OUTPUT=false
SECTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --section=*)
      SECTION="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: ai-documentation-get.sh [OPTIONS]"
      echo
      echo "Options:"
      echo "  --json                 Output in JSON format for MCP integration"
      echo "  --section=SECTION_NAME Filter documentation to a specific section"
      echo "                         (e.g., 'getting-started', 'command-reference')"
      echo "  -h, --help             Show this help message"
      echo
      exit 0
      ;;
    *)
      _red "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Find the README file
REPO_ROOT="$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel 2>/dev/null || echo "")"
README_PATH="$REPO_ROOT/README.md"

if [[ ! -f "$README_PATH" ]]; then
  if $JSON_OUTPUT; then
    printf '{"success": false, "error": "README.md not found at %s"}' "$README_PATH"
    exit 1
  else
    _die "README.md not found at $README_PATH"
  fi
fi

# Read the README file
README_CONTENT=$(cat "$README_PATH")

# Function to extract a section by header ID
extract_section() {
  local header_id="$1"
  local content="$2"
  local section=""
  local capturing=false
  local next_header_level=""
  
  # Find the heading with the specified ID
  while IFS= read -r line; do
    # Check if line is a header
    if [[ "$line" =~ ^"#"+ ]]; then
      # Get the header level (number of # characters)
      header_level=$(echo "$line" | grep -o '^#\+' | wc -c)
      header_level=$((header_level - 1))
      
      # Extract the header text without # marks
      header_text=$(echo "$line" | sed -E 's/^#+\s*//g')
      
      # Convert header to ID format (lowercase, spaces to hyphens)
      header_as_id=$(echo "$header_text" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '-' | sed 's/-*$//g' | sed 's/^-*//g')
      
      if [[ "$capturing" == true ]]; then
        # If we encounter another header at the same or higher level, stop capturing
        if [[ "$header_level" -le "$next_header_level" ]]; then
          break
        fi
      elif [[ "$header_as_id" == "$header_id" ]]; then
        # Found the target section, start capturing
        capturing=true
        section+="$line"$'\n'
        next_header_level="$header_level"
        continue
      fi
    fi
    
    # Add line to section if capturing
    if [[ "$capturing" == true ]]; then
      section+="$line"$'\n'
    fi
  done <<< "$content"
  
  echo "$section"
}

# Process the README content based on section parameter
PROCESSED_CONTENT=""

if [[ -n "$SECTION" ]]; then
  PROCESSED_CONTENT=$(extract_section "$SECTION" "$README_CONTENT")
  
  if [[ -z "$PROCESSED_CONTENT" ]]; then
    if $JSON_OUTPUT; then
      printf '{"success": false, "error": "Section \"%s\" not found in README"}' "$SECTION"
      exit 1
    else
      _die "Section \"$SECTION\" not found in README"
    fi
  fi
else
  PROCESSED_CONTENT="$README_CONTENT"
fi

# Output the result
if $JSON_OUTPUT; then
  # Escape special characters for JSON
  ESCAPED_CONTENT=$(echo "$PROCESSED_CONTENT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
  
  cat <<EOF
{
  "success": true,
  "section": $(if [[ -n "$SECTION" ]]; then echo "\"$SECTION\""; else echo "null"; fi),
  "content": "$ESCAPED_CONTENT"
}
EOF
else
  echo "$PROCESSED_CONTENT"
fi

exit 0