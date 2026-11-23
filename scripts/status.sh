#!/usr/bin/env bash
set -euo pipefail

# Enable ANSI colors only on interactive terminals or when FORCE_COLOR=1 (and respect NO_COLOR)
if [[ (-t 1 || "${FORCE_COLOR:-0}" == "1") && -z "${NO_COLOR:-}" ]]; then
  BOLD='\033[1m'
  GREEN='\033[1;32m'
  YELLOW='\033[1;33m'
  RED='\033[1;31m'
  DIM='\033[2;37m'
  RESET='\033[0m'
else
  BOLD='' GREEN='' YELLOW='' RED='' DIM='' RESET=''
fi

print_header() {
  printf "%b%-16s %-10s %-8s %s%b\n" "$BOLD" "INSTANCE" "STATUS" "PID" "SSH" "$RESET"
  printf "%b%-16s %-10s %-8s %s%b\n" "$DIM" "----------------" "----------" "--------" "----------------" "$RESET"
}

is_ssh_ready() {
  local port="$1"
  timeout 1 bash -c "exec 3<>/dev/tcp/127.0.0.1/${port} && IFS= read -r -n 4 banner <&3 && [[ \"\$banner\" == \"SSH-\" ]]" 2>/dev/null
}

print_row() {
  local color="$1"
  local label="$2"
  local pid="${3:--}"
  local ssh_info="${4:--}"

  printf "%-16s %b%-10s%b %-8s %s\n" "$VM_NAME" "$color" "$label" "$RESET" "$pid" "$ssh_info"
}

if [[ "${1:-}" == "--header" ]]; then
  print_header
  exit 0
fi

if [[ "${1:-}" == "--wait" ]]; then
  VM_NAME="$2"
  PIDFILE="$3"
  SSH_PORT="$4"
  TIMEOUT="${5:-60}"
  SECONDS=0

  while ((SECONDS < TIMEOUT)); do
    if [[ ! -f "$PIDFILE" ]] || ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      printf "\r\033[K%b%s failed to start (process exited).%b\n" "$RED" "$VM_NAME" "$RESET" >&2
      exit 1
    fi

    if is_ssh_ready "$SSH_PORT"; then
      printf "\r\033[K%s %bRUNNING%b (127.0.0.1:%s, ready in %ss)\n" \
        "$VM_NAME" "$GREEN" "$RESET" "$SSH_PORT" "$SECONDS"
      exit 0
    fi

    printf "\r\033[K%s %bBOOTING%b... (%ss/%ss)" \
      "$VM_NAME" "$YELLOW" "$RESET" "$SECONDS" "$TIMEOUT"
    sleep 1
  done

  printf "\r\033[K%bTimed out waiting for %s after %ss.%b\n" "$RED" "$VM_NAME" "$TIMEOUT" "$RESET" >&2
  exit 1
fi

VM_NAME="$1"
PIDFILE="$2"
STOPPING_FILE="$3"
SSH_PORT="$4"

if [[ "${NO_HEADER:-0}" != "1" ]]; then
  print_header
fi

if [[ -f "$PIDFILE" ]]; then
  PID="$(cat "$PIDFILE")"
  if kill -0 "$PID" 2>/dev/null; then
    if [[ -f "$STOPPING_FILE" ]]; then
      print_row "$YELLOW" "STOPPING" "$PID" "-"
    elif is_ssh_ready "$SSH_PORT"; then
      print_row "$GREEN" "RUNNING" "$PID" "127.0.0.1:${SSH_PORT}"
    else
      print_row "$YELLOW" "BOOTING" "$PID" "-"
    fi
    exit 0
  else
    rm -f "$PIDFILE"
    if [[ -f "$STOPPING_FILE" ]]; then
      rm -f "$STOPPING_FILE"
      print_row "$DIM" "STOPPED" "-" "-"
    else
      print_row "$RED" "CRASHED" "-" "stale PID ${PID} cleaned"
    fi
    exit 0
  fi
fi

rm -f "$STOPPING_FILE"
print_row "$DIM" "STOPPED" "-" "-"
