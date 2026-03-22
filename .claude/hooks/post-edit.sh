#!/usr/bin/env bash
# Post-edit hook: auto-fix and validate files after edits
set -euo pipefail

FILE="$TOOL_INPUT_FILE_PATH"

case "$FILE" in
    *.sh)
        if command -v shellharden > /dev/null 2>&1; then
            shellharden --replace "$FILE" 2>/dev/null || true
        fi
        if [ -f "$FILE" ] && head -1 "$FILE" | grep -q '^#!'; then
            chmod +x "$FILE"
        fi
        ;;
    *.md)
        if command -v markdownlint > /dev/null 2>&1; then
            markdownlint --fix "$FILE" 2>/dev/null || true
        fi
        ;;
    *.tf)
        if command -v terraform > /dev/null 2>&1; then
            terraform fmt "$FILE" 2>/dev/null || true
        fi
        ;;
    policies/*.json)
        if command -v python3 > /dev/null 2>&1; then
            if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$FILE" 2>/dev/null; then
                echo "Warning: $FILE is not valid JSON" >&2
            fi
        fi
        ;;
esac
