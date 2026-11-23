#!/usr/bin/env bash
set -euo pipefail

ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
START_MARK="# >>> VMLabs >>>"
END_MARK="# <<< VMLabs <<<"

if [[ ! -f "$ZSHRC" ]] || ! grep -Fq "$START_MARK" "$ZSHRC"; then
  echo "No VMLabs entry found in ${ZSHRC}."
  exit 0
fi

TMP_FILE="$(mktemp)"
awk -v start="$START_MARK" -v end="$END_MARK" '
  $0 == start { skip=1; next }
  $0 == end   { skip=0; next }
  !skip       { print }
' "$ZSHRC" >"$TMP_FILE"

mv "$TMP_FILE" "$ZSHRC"
echo "Removed VMLabs from ${ZSHRC}."
echo "Your disks, ISOs, and instance configs were left untouched."
echo "Reload your shell: source \"${ZSHRC}\""
