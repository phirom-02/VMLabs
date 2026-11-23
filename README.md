# VMLabs

A lightweight, declarative multi-instance KVM/QEMU virtual machine manager built with GNU Make. Define each VM as a small `.mk` profile and manage its full lifecycle from anywhere in your terminal.

## Features

- **Declarative Profiles:** Configure CPU, RAM, disk path, network model, port forwarding, and default SSH user per VM in `instances/*.mk`.
- **Headless & Display Modes:** Launch VMs silently in the background (`vm start`) or with a graphical window (`vm display`).
- **Default Profile Switching:** Set an active default VM with `vm use <instance>` and override it per command when needed.
- **Interactive SSH User Prompting:** Confirm or override the SSH user at boot (defaulting to `DEFAULT_SSH_USER`), then reuse it automatically for `console`, `stop`, and `restart`.
- **Live 5-State Status Table:** Color-coded status output distinguishing `BOOTING`, `RUNNING`, `STOPPING`, `STOPPED`, and `CRASHED` via PID tracking and SSH banner checks.
- **Loopback-Only Port Forwarding:** Binds forwarded SSH and HTTP ports strictly to `127.0.0.1` so guest services are not exposed on your LAN.
- **Portable & Self-Contained:** Auto-detects the clone directory, includes Zsh tab completion, and ships with idempotent `install.sh` and `uninstall.sh` scripts.

## Directory Structure

```text
VMLabs/
├── Makefile                        # Core KVM/QEMU orchestration targets
├── install.sh                      # Idempotent setup script
├── uninstall.sh                    # Cleanly removes shell integration
├── instances/
│   └── debian-lab.mk.example       # Template VM profile
├── scripts/
│   ├── vm.zsh                      # Zsh CLI wrapper and tab completion
│   └── status.sh                   # Color-coded 5-state status table
├── disks/                          # qcow2 disk images (gitignored)
├── iso/                            # OS installation ISOs (gitignored)
├── run/                            # Runtime PID, user, and state files (gitignored)
└── backups/                        # qcow2 disk backups (gitignored)
```

## Prerequisites

- Linux host with hardware virtualization enabled (`/dev/kvm`)
- `qemu-system-x86_64` and `qemu-img`
- `make`
- `openssh-client`
- `zsh`

Install dependencies for your distribution:

**Debian / Ubuntu**
```bash
sudo apt update && sudo apt install -y qemu-system-x86 qemu-utils make openssh-client zsh
```

**Fedora**
```bash
sudo dnf install -y qemu-system-x86 qemu-img make openssh-clients zsh
```

**Arch Linux**
```bash
sudo pacman -S qemu-full make openssh zsh
```

Make sure your user has permission to access `/dev/kvm`:

```bash
sudo usermod -aG kvm "$USER"
newgrp kvm
```

## Installation

Clone the repository anywhere on your machine and run `install.sh`:

```bash
git clone [https://github.com/](https://github.com/)<your-username>/VMLabs.git ~/VMLabs
cd ~/VMLabs
./install.sh
source ~/.zshrc
```

`install.sh` creates the required runtime directories, sets executable permissions on `scripts/*.sh`, checks for missing dependencies, and adds a marked block to your `~/.zshrc`.

## Creating an Instance

1. **Copy the example profile:**
   ```bash
   cp instances/debian-lab.mk.example instances/debian-lab.mk
   ```

2. **Edit `instances/debian-lab.mk`:**
   ```makefile
   VM_NAME          := debian-lab
   DISK             := disks/debian-lab.qcow2
   RAM              := 2048
   CPUS             := 2
   DEFAULT_SSH_USER := admin
   SSH_PORT         := 2222
   HTTP_PORT        := 8080
   NETWORK_MODEL    := virtio-net-pci
   ```

3. **Create a `qcow2` disk image** (if you do not already have one):
   ```bash
   qemu-img create -f qcow2 disks/debian-lab.qcow2 20G
   ```

## Usage

### Set a Default Instance

```zsh
vm use debian-lab    # saves default instance to .default
vm use               # shows current default instance
```

Once a default is set, `[instance]` is optional for all commands. Pass another instance name at any time for a one-off override (for example, `vm start ubuntu-test`).

### CLI Reference

| Command | Description |
| :--- | :--- |
| `vm use [instance]` | Set or display the default VM instance |
| `vm list` | List all configured instances in `instances/` |
| `vm status [instance]` | Show status table (all instances if omitted) |
| `vm check [instance]` | Validate profile, disk image, QEMU binary, and `/dev/kvm` |
| `vm start [instance]` | Start the VM headless in the background |
| `vm display [instance]` | Start the VM with a graphical display window |
| `vm console [instance]` | Connect to the VM via SSH (`127.0.0.1:SSH_PORT`) |
| `vm stop [instance]` | Gracefully shut down the VM via SSH |
| `vm restart [instance]` | Stop and restart the VM (reuses the active SSH user) |
| `vm backup [instance]` | Create a `qcow2` backup in `backups/` (VM must be stopped) |
| `vmlab` | Alias to `cd` into the VMLabs directory |

### Status Table

Running `vm status` inspects each VM's PID, shutdown state, and SSH banner:

```text
INSTANCE         STATUS     PID      SSH
---------------- ---------- -------- ----------------
debian-lab       RUNNING    18422    127.0.0.1:2222
ubuntu-test      BOOTING    19014    -
docker-node      STOPPING   17301    -
arch-box         STOPPED    -        -
```

| State | Meaning |
| :--- | :--- |
| `BOOTING` | QEMU process is alive, waiting for the guest SSH daemon |
| `RUNNING` | Guest SSH daemon is responding on `127.0.0.1:SSH_PORT` |
| `STOPPING` | Graceful shutdown command was sent, waiting for exit |
| `STOPPED` | VM is powered off cleanly |
| `CRASHED` | Stale PID detected without a shutdown marker (automatically cleaned) |

### SSH User Resolution

On `vm start` or `vm display`, VMLabs prompts for the SSH username with `DEFAULT_SSH_USER` pre-filled—press `Enter` to accept or type a different user for that session. The selected user is saved to `run/<vm>.user` and reused by `vm console`, `vm stop`, and `vm restart`.

To skip the prompt when invoking `make` directly:

```bash
make start INSTANCE=debian-lab SSH_USER=admin
```

## Guest Setup for Graceful Shutdown (`vm stop`)

`vm stop` runs `sudo /usr/sbin/shutdown -h now` over non-interactive SSH. Inside your guest VM, allow passwordless shutdown for your user:

```bash
echo "<user> ALL=(ALL) NOPASSWD: /usr/sbin/shutdown" | sudo tee /etc/sudoers.d/<user>-shutdown
sudo chmod 440 /etc/sudoers.d/<user>-shutdown
```

For passwordless SSH login from your host:

```bash
ssh-copy-id -p 2222 <user>@127.0.0.1
```

## Uninstall

Remove the VMLabs block from `~/.zshrc` without touching your disks, ISOs, or instance profiles:

```bash
cd ~/VMLabs
./uninstall.sh
source ~/.zshrc
```

## License

MIT
