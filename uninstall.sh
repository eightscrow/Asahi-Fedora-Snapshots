#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

is_fedora || die "This uninstall script supports Fedora only."

log "Stopping and disabling timers/services"
run_sudo systemctl stop snapper-timeline.timer snapper-cleanup.timer grub-btrfsd.service 2>/dev/null || true
run_sudo systemctl disable snapper-timeline.timer snapper-cleanup.timer grub-btrfsd.service 2>/dev/null || true

if command -v snapper >/dev/null 2>&1; then
  log "Deleting snapper configs"
  run_sudo snapper -c root delete-config 2>/dev/null || true
  run_sudo snapper -c home delete-config 2>/dev/null || true
fi

if command -v btrfs >/dev/null 2>&1; then
  log "Removing snapshot subvolumes"
  for snap in $(run_sudo btrfs subvolume list / 2>/dev/null | awk '/snapshots.*snapshot$/ {print $NF}' | sort -r); do
    run_sudo btrfs subvolume delete "/$snap" 2>/dev/null || true
  done
  run_sudo btrfs subvolume delete /.snapshots 2>/dev/null || true
  run_sudo btrfs subvolume delete /home/.snapshots 2>/dev/null || true
fi

log "Removing grub-btrfs files"
run_sudo rm -rf /etc/default/grub-btrfs
run_sudo rm -f /etc/grub.d/41_snapshots-btrfs /etc/grub.d/10_linux_btrfs
run_sudo rm -f /usr/bin/grub-btrfsd /usr/bin/grub-btrfs.path
run_sudo rm -f /usr/lib/systemd/system/grub-btrfsd.service /usr/lib/systemd/system/grub-btrfs.path

log "Removing Fedora packages"
run_sudo dnf remove -y snapper python3-dnf-plugin-snapper btrfs-assistant inotify-tools 2>/dev/null || true

log "Regenerating clean GRUB config"
if [[ -d /boot/grub2 ]]; then
  run_sudo grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null
fi

log "Uninstall complete"
