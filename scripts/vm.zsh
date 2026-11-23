export VMLABS_DIR="${${(%):-%x}:A:h:h}"
export VMLABS_DEFAULT_FILE="$VMLABS_DIR/.default"alias vmlab='cd "$VMLABS_DIR"'

unalias vm 2>/dev/null
vm() {
  local cmd="$1"
  local instance="$2"

  if [[ -z "$cmd" || "$cmd" == "-h" || "$cmd" == "--help" || "$cmd" == "help" ]]; then
    echo "Usage: vm <command> [instance]"
    echo ""
    echo "Commands:"
    echo "  use [instance]      Set or show the default instance"
    echo "  list                List available instances"
    echo "  status [instance]   Show status (all instances if omitted)"
    echo "  check [instance]    Validate instance config and disk"
    echo "  start [instance]    Start VM in background (headless)"
    echo "  display [instance]  Start VM with a display window"
    echo "  stop [instance]     Gracefully shut down VM via SSH"
    echo "  restart [instance]  Stop and start VM"
    echo "  console [instance]  SSH into VM"
    echo "  backup [instance]   Create qcow2 backup (VM must be stopped)"
    return 0
  fi

  case "$cmd" in
    use)
      if [[ -z "$instance" ]]; then
        if [[ -s "$VMLABS_DEFAULT_FILE" ]]; then
          echo "Default instance: $(<"$VMLABS_DEFAULT_FILE")"
        else
          echo "No default instance set. Run: vm use <instance>"
        fi
        return 0
      fi

      if [[ ! -f "$VMLABS_DIR/instances/${instance}.mk" ]]; then
        echo "Error: instance '$instance' not found in $VMLABS_DIR/instances/" >&2
        return 1
      fi

      print -r -- "$instance" > "$VMLABS_DEFAULT_FILE"
      echo "Default instance set to: $instance"
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
            if [[ -n "$2" ]]; then
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
    check|start|display|stop|restart|console|backup)
      if [[ -z "$instance" && -s "$VMLABS_DEFAULT_FILE" ]]; then
        instance="$(<"$VMLABS_DEFAULT_FILE")"
      fi

      if [[ -z "$instance" ]]; then
        echo "Error: specify an instance or set a default with 'vm use <instance>'" >&2
        return 1
      fi

      make -C "$VMLABS_DIR" --no-print-directory "$cmd" INSTANCE="$instance"
      ;;
    *)
      echo "Unknown command: $cmd (run 'vm help')" >&2
      return 1
      ;;
  esac
}

# Zsh tab-completion for `vm`
_vm() {
  local -a commands instances

  commands=(
    'use:Set or show the default instance'
    'list:List available instances'
    'status:Show VM running status'
    'check:Validate instance config and disk'
    'start:Start VM in background'
    'display:Start VM with display window'
    'stop:Gracefully shut down VM via SSH'
    'restart:Restart VM'
    'console:SSH into VM'
    'backup:Backup qcow2 disk'
    'help:Show usage'
  )

  if (( CURRENT == 2 )); then
    _describe 'command' commands
  elif (( CURRENT == 3 )) && [[ "${words[2]}" != "list" && "${words[2]}" != "help" ]]; then
    instances=( "$VMLABS_DIR"/instances/*.mk(N:t:r) )
    _describe 'instance' instances
  fi
}

(( $+functions[compdef] )) && compdef _vm vm
