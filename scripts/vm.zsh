# ==========================================
# VMLabs - Zsh CLI Wrapper & Tab Completion
# ==========================================

export VMLABS_DIR="${${(%):-%x}:A:h:h}"
export VMLABS_DEFAULT_FILE="$VMLABS_DIR/.default"

alias vmlab='cd "$VMLABS_DIR"'

vm() {
  local cmd="${1:-help}"

  case "$cmd" in
    use)
      local target="${2:-}"
      if [[ -z "$target" ]]; then
        if [[ -s "$VMLABS_DEFAULT_FILE" ]]; then
          echo "Default VM instance: $(cat "$VMLABS_DEFAULT_FILE")"
        else
          echo "No default VM instance set. Run: vm use <instance>"
        fi
        return 0
      fi

      if [[ ! -f "$VMLABS_DIR/instances/${target}.mk" ]]; then
        echo "Instance not found: $target" >&2
        return 1
      fi

      printf '%s\n' "$target" > "$VMLABS_DEFAULT_FILE"
      echo "Default VM instance set to: $target"
      ;;

    list)
      make -C "$VMLABS_DIR" --no-print-directory list
      ;;

    status)
      local watch_mode=0 interval=2 target=""
      shift
      while (( $# > 0 )); do
        case "$1" in
          -w|--watch) watch_mode=1 ;;
          -n|--interval)
            if [[ -n "${2:-}" ]]; then
              interval="$2"
              shift
            fi
            ;;
          *) target="$1" ;;
        esac
        shift
      done

      if (( ! watch_mode )); then
        if [[ -n "$target" ]]; then
          make -C "$VMLABS_DIR" --no-print-directory status INSTANCE="$target"
        else
          local -a files=( "$VMLABS_DIR"/instances/*.mk(N) )
          if (( ${#files} == 0 )); then
            echo "No VM instances found in $VMLABS_DIR/instances/"
            return 0
          fi

          "$VMLABS_DIR/scripts/status.sh" --header
          local f name
          for f in "${files[@]}"; do
            name="${f:t:r}"
            make -C "$VMLABS_DIR" --no-print-directory status INSTANCE="$name" NO_HEADER=1
          done
        fi
        return 0
      fi

      # Live polling loop in a subshell so Ctrl+C exits cleanly without altering shell traps
      (
        trap 'exit 0' INT
        local out f name row
        local -a files
        while true; do
          if [[ -n "$target" ]]; then
            out="$(make -C "$VMLABS_DIR" --no-print-directory status INSTANCE="$target" FORCE_COLOR=1)"
          else
            files=( "$VMLABS_DIR"/instances/*.mk(N) )
            if (( ${#files} == 0 )); then
              out="No VM instances found in $VMLABS_DIR/instances/"
            else
              out="$(FORCE_COLOR=1 "$VMLABS_DIR/scripts/status.sh" --header)"
              for f in "${files[@]}"; do
                name="${f:t:r}"
                row="$(make -C "$VMLABS_DIR" --no-print-directory status INSTANCE="$name" NO_HEADER=1 FORCE_COLOR=1)"
                out+=$'\n'"$row"
              done
            fi
          fi

          printf '\033[H\033[2J'
          printf 'VMLabs Status (every %ss | %s | Ctrl+C to exit)\n\n' "$interval" "$(date +%H:%M:%S)"
          printf '%s\n' "$out"
          sleep "$interval"
        done
      )
      ;;

    start)
      local wait_flag=0 timeout="" target=""
      shift
      while (( $# > 0 )); do
        case "$1" in
          -aw|--await) wait_flag=1 ;;
          -t|--timeout)
            if [[ -n "${2:-}" ]]; then
              timeout="$2"
              shift
            fi
            ;;
          *) target="$1" ;;
        esac
        shift
      done

      local -a make_args=( -C "$VMLABS_DIR" --no-print-directory start )
      [[ -n "$target" ]] && make_args+=( INSTANCE="$target" )
      (( wait_flag )) && make_args+=( WAIT=1 )
      [[ -n "$timeout" ]] && make_args+=( WAIT_TIMEOUT="$timeout" )

      make "${make_args[@]}"
      ;;

    display|check|stop|restart|console|backup)
      local target="${2:-}"
      if [[ -n "$target" ]]; then
        make -C "$VMLABS_DIR" --no-print-directory "$cmd" INSTANCE="$target"
      else
        make -C "$VMLABS_DIR" --no-print-directory "$cmd"
      fi
      ;;

    help|-h|--help)
      echo "VMLabs - Multi-instance KVM/QEMU Manager"
      echo ""
      echo "Usage: vm <command> [options] [instance]"
      echo ""
      echo "Commands:"
      echo "  use [instance]                    Set or show the default VM instance"
      echo "  list                              List all configured instances"
      echo "  status [-w] [-n sec] [instance]   Show status (-w to watch live)"
      echo "  check [instance]                  Validate profile, disk, and KVM"
      echo "  start [-aw] [-t sec] [instance]   Start headless (-aw to wait until running)"
      echo "  display [instance]                Start with a graphical display window"
      echo "  console [instance]                Connect to the VM via SSH"
      echo "  stop [instance]                   Gracefully shut down via SSH"
      echo "  restart [instance]                Stop and restart the VM"
      echo "  backup [instance]                 Create a qcow2 backup (VM must be stopped)"
      echo "  help                              Show this help message"
      ;;

    *)
      echo "Unknown command: $cmd" >&2
      echo "Run 'vm help' to see available commands." >&2
      return 1
      ;;
  esac
}

# ==========================================
# Zsh Tab Completion
# ==========================================

_vm() {
  local -a commands instances flags
  commands=(
    'use:Set or show the default VM instance'
    'list:List all configured instances'
    'status:Show VM status (-w to watch live)'
    'check:Validate profile, disk, and KVM'
    'start:Start VM headless (-aw to await boot)'
    'display:Start VM with display window'
    'console:Connect to the VM via SSH'
    'stop:Gracefully shut down the VM'
    'restart:Stop and restart the VM'
    'backup:Create a qcow2 backup'
    'help:Show usage help'
  )

  if (( CURRENT == 2 )); then
    _describe -t commands 'vm commands' commands
    return
  fi

  local subcmd="${words[2]}"
  instances=( "$VMLABS_DIR"/instances/*.mk(N:t:r) )

  case "$subcmd" in
    status)
      flags=( '-w:Watch status live' '--watch:Watch status live' '-n:Polling interval in seconds' '--interval:Polling interval in seconds' )
      _describe -t flags 'status options' flags
      _describe -t instances 'vm instances' instances
      ;;
    start)
      flags=( '-aw:Wait until SSH is ready' '--await:Wait until SSH is ready' '-t:Timeout in seconds' '--timeout:Timeout in seconds' )
      _describe -t flags 'start options' flags
      _describe -t instances 'vm instances' instances
      ;;
    use|check|display|console|stop|restart|backup)
      _describe -t instances 'vm instances' instances
      ;;
  esac
}

(( $+functions[compdef] )) && compdef _vm vm
