# ==========================================
# VMLabs - Multi-instance KVM Manager
# ==========================================

PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

DEFAULT_INSTANCE := $(shell cat $(PROJECT_DIR)/.default 2>/dev/null)
INSTANCE ?= $(DEFAULT_INSTANCE)
INSTANCE_CONF := $(PROJECT_DIR)/instances/$(INSTANCE).mk

-include $(INSTANCE_CONF)

KVM ?= qemu-system-x86_64 -enable-kvm
QEMU_IMG ?= qemu-img

DISK_PATH := $(PROJECT_DIR)/$(DISK)
PID_DIR := $(PROJECT_DIR)/run
PIDFILE := $(PID_DIR)/$(VM_NAME).pid
STOPPING_FILE := $(PID_DIR)/$(VM_NAME).stopping
USER_FILE := $(PID_DIR)/$(VM_NAME).user

KVM_FLAGS = \
	-name $(VM_NAME) \
	-m $(RAM) \
	-smp $(CPUS) \
	-drive file=$(DISK_PATH),format=qcow2 \
	-netdev user,id=net0,hostfwd=tcp:127.0.0.1:$(SSH_PORT)-:22,hostfwd=tcp:127.0.0.1:$(HTTP_PORT)-:80 \
	-device $(NETWORK_MODEL),netdev=net0 \
	-pidfile $(PIDFILE)

# ==========================================
# Targets
# ==========================================

.PHONY: all list check start display stop restart status console backup

all: check start

# List available instances
list:
	@echo "Available VM instances:"
	@for f in $(PROJECT_DIR)/instances/*.mk; do \
		[ -f "$$f" ] && basename "$$f" .mk; \
	done

# Check environment and configuration
check:
	@test -n "$(INSTANCE)" || (echo "Specify an instance or set a default with 'vm use <instance>'" && exit 1)
	@test -f "$(INSTANCE_CONF)" || (echo "Instance not found: $(INSTANCE)" && exit 1)
	@test -n "$(VM_NAME)" || (echo "VM_NAME missing" && exit 1)
	@test -f "$(DISK_PATH)" || (echo "Disk not found: $(DISK_PATH)" && exit 1)
	@command -v $(firstword $(KVM)) >/dev/null || (echo "$(firstword $(KVM)) not installed" && exit 1)
	@test -e /dev/kvm || (echo "KVM unavailable (/dev/kvm not found)" && exit 1)
	@echo "Instance $(INSTANCE) is ready."

# Start VM (headless)
start: check
	@mkdir -p "$(PID_DIR)"
	@if [ -f "$(PIDFILE)" ] && kill -0 "$$(cat "$(PIDFILE)")" 2>/dev/null; then \
		echo "$(VM_NAME) is already running."; exit 0; \
	fi
	@if [ -n "$(SSH_USER)" ]; then \
		printf '%s\n' "$(SSH_USER)" > "$(USER_FILE)"; \
	else \
		default_user="$(DEFAULT_SSH_USER)"; \
		if [ -z "$$default_user" ] && [ -s "$(USER_FILE)" ]; then \
			default_user="$$(cat "$(USER_FILE)")"; \
		fi; \
		default_user="$${default_user:-$$USER}"; \
		printf "SSH user for $(VM_NAME) [%s]: " "$$default_user"; \
		read -r input_user; \
		printf '%s\n' "$${input_user:-$$default_user}" > "$(USER_FILE)"; \
	fi
	@rm -f "$(STOPPING_FILE)"
	$(KVM) $(KVM_FLAGS) -display none -daemonize

# Start VM with display window
display: check
	@mkdir -p "$(PID_DIR)"
	@if [ -f "$(PIDFILE)" ] && kill -0 "$$(cat "$(PIDFILE)")" 2>/dev/null; then \
		echo "$(VM_NAME) is already running."; exit 0; \
	fi
	@if [ -n "$(SSH_USER)" ]; then \
		printf '%s\n' "$(SSH_USER)" > "$(USER_FILE)"; \
	else \
		default_user="$(DEFAULT_SSH_USER)"; \
		if [ -z "$$default_user" ] && [ -s "$(USER_FILE)" ]; then \
			default_user="$$(cat "$(USER_FILE)")"; \
		fi; \
		default_user="$${default_user:-$$USER}"; \
		printf "SSH user for $(VM_NAME) [%s]: " "$$default_user"; \
		read -r input_user; \
		printf '%s\n' "$${input_user:-$$default_user}" > "$(USER_FILE)"; \
	fi
	@rm -f "$(STOPPING_FILE)"
	$(KVM) $(KVM_FLAGS) >/dev/null 2>&1 &

# VM status
status:
	@NO_HEADER="$(NO_HEADER)" FORCE_COLOR="$(FORCE_COLOR)" "$(PROJECT_DIR)/scripts/status.sh" "$(VM_NAME)" "$(PIDFILE)" "$(STOPPING_FILE)" "$(SSH_PORT)"

# SSH connection
console:
	@if [ ! -f "$(PIDFILE)" ] || ! kill -0 "$$(cat "$(PIDFILE)")" 2>/dev/null; then \
		echo "$(VM_NAME) is not running. Start it with: vm start $(INSTANCE)"; \
		exit 1; \
	fi
	@user="$(SSH_USER)"; \
	if [ -z "$$user" ] && [ -s "$(USER_FILE)" ]; then \
		user="$$(cat "$(USER_FILE)")"; \
	fi; \
	if [ -z "$$user" ]; then \
		user="$(DEFAULT_SSH_USER)"; \
	fi; \
	if [ -z "$$user" ]; then \
		printf "SSH user for $(VM_NAME) [%s]: " "$$USER"; \
		read -r input_user; \
		user="$${input_user:-$$USER}"; \
		printf '%s\n' "$$user" > "$(USER_FILE)"; \
	fi; \
	exec ssh -p "$(SSH_PORT)" "$$user@127.0.0.1"

# Graceful shutdown
stop:
	@if [ ! -f "$(PIDFILE)" ] || ! kill -0 "$$(cat "$(PIDFILE)")" 2>/dev/null; then \
		rm -f "$(PIDFILE)" "$(STOPPING_FILE)"; \
		echo "$(VM_NAME) is not running."; \
		exit 0; \
	fi
	@user="$(SSH_USER)"; \
	if [ -z "$$user" ] && [ -s "$(USER_FILE)" ]; then \
		user="$$(cat "$(USER_FILE)")"; \
	fi; \
	if [ -z "$$user" ]; then \
		user="$(DEFAULT_SSH_USER)"; \
	fi; \
	if [ -z "$$user" ]; then \
		printf "SSH user for $(VM_NAME) [%s]: " "$$USER"; \
		read -r input_user; \
		user="$${input_user:-$$USER}"; \
	fi; \
	touch "$(STOPPING_FILE)"; \
	ssh -p "$(SSH_PORT)" "$$user@127.0.0.1" "sudo /usr/sbin/shutdown -h now"

# Restart VM (reuses saved SSH user without re-prompting)
restart: stop
	@sleep 5
	@$(MAKE) INSTANCE="$(INSTANCE)" SSH_USER="$$(cat "$(USER_FILE)" 2>/dev/null)" start

# Backup (requires stopped VM)
backup:
	@test -f "$(DISK_PATH)" || (echo "Disk not found" && exit 1)
	@mkdir -p "$(PROJECT_DIR)/backups"
	@test ! -f "$(PIDFILE)" || ! kill -0 "$$(cat "$(PIDFILE)")" 2>/dev/null || (echo "Stop VM before backup" && exit 1)
	$(QEMU_IMG) convert -p -O qcow2 \
		"$(DISK_PATH)" \
		"$(PROJECT_DIR)/backups/$(VM_NAME)-backup.qcow2"
