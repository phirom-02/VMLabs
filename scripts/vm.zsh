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
      if [[ -n "$instance" ]]; then
        make -C "$VMLABS_DIR" --no-print-directory status INSTANCE="$instance"
      else
        local f name
        for f in "$VMLABS_DIR"/instances/*.mk(N); do
          name="${f:t:r}"
          make -C "$VMLABS_DIR" --no-print-directory status INSTANCE="$name"
        done
      fi
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
