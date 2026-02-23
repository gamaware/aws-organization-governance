#!/usr/bin/env bash
set -euo pipefail

# Check drift plan exit code and set output
# Requires PLAN_EXIT_CODE env var

if [ "$PLAN_EXIT_CODE" == "2" ]; then
  echo "has_drift=true" >> "$GITHUB_OUTPUT"
  echo "⚠️ Configuration drift detected!"
else
  echo "has_drift=false" >> "$GITHUB_OUTPUT"
  echo "✅ No drift detected"
fi
