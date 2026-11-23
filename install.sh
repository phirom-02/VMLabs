#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
START_MARK="# >>> VMLabs >>>"
END_MARK="# <<< VMLabs <<<"

echo "Installing VMLabs from ${PROJECT_DIR}..."

mkdir -p "${PROJECT_DIR}/disks" \
  "${PROJECT_DIR}/iso" \
  "${PROJECT_DIR}/run" \
  "${PROJECT_DIR}/backups" \
  "${PROJECT_DIR}/instances"

shopt -s nullglob
for script in "${PROJECT_DIR}"/scripts/*.sh; do
  chmod +x "$script"
done
shopt -u nullglob

# Dependency check
MISSING=()
for cmd in qemu-system-x86_64 qemu-img make ssh zsh; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING+=("$cmd")
done

if ((${#MISSING[@]} > 0)); then
  echo "Warning: missing commands: ${MISSING[*]}"
fi

if [[ ! -e /dev/kvm ]]; then
  echo "Warning: /dev/kvm not found (enable VT-x/AMD-V in BIOS)."
elif [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
  echo "Warning: no read/write access to /dev/kvm. Run: sudo usermod -aG kvm \"\$USER\""
fi

# Idempotent ~/.zshrc block
touch "$ZSHRC"
if grep -Fq "$START_MARK" "$ZSHRC"; then
  echo "  [skip] VMLabs block already exists in ${ZSHRC}"
else
  {
    echo ""
    echo "$START_MARK"
    echo "[[ -f \"${PROJECT_DIR}/scripts/vm.zsh\" ]] && source \"${PROJECT_DIR}/scripts/vm.zsh\""
    echo "$END_MARK"
  } >>"$ZSHRC"
  echo "  [added] VMLabs block to ${ZSHRC}"
fi

echo "Done. Reload your shell: source \"${ZSHRC}\""
