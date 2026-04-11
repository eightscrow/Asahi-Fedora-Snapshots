# Boot entry Snapshots for Asahi Fedora

Installs and configures snapper + grub-btrfs on Asahi Fedora so BTRFS snapshots show up as boot entries in GRUB.

## Requirements

- Asahi Fedora
- BTRFS root filesystem
- GRUB2 bootloader
- sudo access

## Install

```bash
git clone https://github.com/eightscrow/Asahi-Fedora-Snapshots.git && cd Asahi-Fedora-Snapshots && bash install.sh
```

## What it does

1. Installs Fedora packages for snapshot workflow (`snapper`, `python3-dnf-plugin-snapper`, `btrfs-assistant`, `inotify-tools`, GRUB tools, build deps)
2. Creates snapper configs for `/` and `/home` (if `/home` is also BTRFS)
3. Applies retention policies for root and home snapshots
4. Enables `snapper-timeline.timer` and `snapper-cleanup.timer`
5. Builds and installs `grub-btrfs` from upstream repository `https://github.com/Antynea/grub-btrfs` (via `git clone --depth=1`) when missing
6. Writes Fedora-specific grub-btrfs config for `/boot/grub2` and `grub2-mkconfig`
7. Creates bootstrap snapshots for root and home when needed
8. Regenerates `/boot/grub2/grub.cfg` and enables `grub-btrfsd` when available

After install, you should see a snapshots submenu in GRUB.

## Uninstall

```bash
bash uninstall.sh
```

Removes snapper/grub-btrfs setup, snapshot subvolumes, related packages, and regenerates a clean GRUB config.

## Verify

```bash
bash scripts/verify.sh
```
