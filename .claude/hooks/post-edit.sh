#!/usr/bin/env bash
# Post-edit hook: auto-fix and validate files after edits
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || FILE_PATH=""

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Auto-fix shell scripts with shellharden and restore executable permissions
if [[ "$FILE_PATH" =~ \.sh$ ]]; then
  shellharden --replace "$FILE_PATH" 2>/dev/null || true
  chmod +x "$FILE_PATH"
fi

# Auto-fix markdown with markdownlint
if [[ "$FILE_PATH" =~ \.md$ ]]; then
  npx markdownlint --fix "$FILE_PATH" 2>/dev/null || true
fi

# Auto-format Terraform files
if [[ "$FILE_PATH" =~ \.tf$ ]]; then
  terraform fmt "$FILE_PATH" 2>/dev/null || true
fi

# Validate JSON policy files
if [[ "$FILE_PATH" =~ policies/.*\.json$ ]]; then
  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$FILE_PATH" 2>/dev/null; then
    echo "Warning: $FILE_PATH is not valid JSON" >&2
  fi
fi
