# TODO

Roadmap and planned improvements for **VMLabs**.

## Bash Shell Support

### CLI & Completion
- [ ] Create `scripts/vm.bash` with dynamic `VMLABS_DIR` detection (`BASH_SOURCE[0]`)
- [ ] Port the `vm()` function from Zsh syntax to Bash (`printf`, `nullglob`, `basename`)
- [ ] Implement Bash tab-completion using `complete -F _vm vm` (`COMP_CWORD`, `COMPREPLY`, `compgen -W`)

### Install & Uninstall
- [ ] Update `install.sh` to detect Bash/Zsh (or accept a `--shell` flag) and target `~/.bashrc`
- [ ] Remove the hard dependency warning on `zsh` in `install.sh`
- [ ] Update `uninstall.sh` to clean VMLabs marker blocks from both `~/.bashrc` and `~/.zshrc`

### Testing & Docs
- [ ] Test `vm` commands and tab-completion in a clean Bash session (`bash --norc`)
- [ ] Update `README.md` with Bash prerequisites, directory structure, and `source ~/.bashrc` instructions

## Future Enhancements

- [ ] Add `vm install` target to create a `qcow2` disk and boot a new VM from an ISO with display
- [ ] Support graceful ACPI shutdown via QEMU monitor socket (`system_powerdown`) without requiring SSH/`sudo`
- [ ] Replace `sleep 5` in `restart` with a PID exit wait loop
